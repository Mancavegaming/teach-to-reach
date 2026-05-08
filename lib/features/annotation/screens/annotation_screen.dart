import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/lesson.dart';
import '../../../models/sermon_annotation.dart';
import '../../../services/ai_pen_revision_service.dart';
import '../../../services/annotation_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/class_profile_service.dart';
import '../../../services/doctrinal_positions_service.dart';
import '../../../services/lesson_service.dart';
import '../../../services/teacher_profile_service.dart';
import '../../../services/voice_corpus_service.dart';
import '../widgets/ink_canvas.dart';

class AnnotationScreen extends StatefulWidget {
  final Lesson lesson;
  const AnnotationScreen({super.key, required this.lesson});

  @override
  State<AnnotationScreen> createState() => _AnnotationScreenState();
}

class _AnnotationScreenState extends State<AnnotationScreen> {
  final List<InkStroke> _strokes = [];
  Color _inkColor = const Color(0xFFEF4444);
  bool _penMode = true;
  bool _saving = false;
  bool _submitting = false;
  Size? _capturedCanvasSize;
  bool _loading = true;
  late Lesson _lesson;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final ownerId = context.read<AuthService>().user!.uid;
    final svc = context.read<AnnotationService>();
    await svc.loadForLesson(ownerId, _lesson.id!);
    final latest = svc.latestFor(_lesson.id!);
    if (mounted) {
      setState(() {
        if (latest != null) {
          _strokes.addAll(latest.strokes);
          _capturedCanvasSize =
              Size(latest.canvasWidth, latest.canvasHeight);
        }
        _loading = false;
      });
    }
  }

  void _onStrokeFinished(InkStroke stroke) {
    setState(() => _strokes.add(stroke));
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  void _clear() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.clear());
  }

  Future<void> _save() async {
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nothing to save — draw something first.')),
      );
      return;
    }
    if (_capturedCanvasSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Canvas not ready yet.')),
      );
      return;
    }
    setState(() => _saving = true);
    final ownerId = context.read<AuthService>().user!.uid;
    final svc = context.read<AnnotationService>();
    final messenger = ScaffoldMessenger.of(context);
    final id = await svc.saveNewVersion(SermonAnnotation(
      ownerId: ownerId,
      lessonId: _lesson.id!,
      version: 1,
      canvasWidth: _capturedCanvasSize!.width,
      canvasHeight: _capturedCanvasSize!.height,
      strokes: List.of(_strokes),
    ));
    if (!mounted) return;
    setState(() => _saving = false);
    messenger.showSnackBar(
      SnackBar(content: Text(id == null ? 'Save failed' : 'Annotation saved')),
    );
  }

  Future<void> _submitForRevision() async {
    if (_strokes.isEmpty || _capturedCanvasSize == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draw your edits first.')),
      );
      return;
    }
    if (_lesson.finalizedSermonText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Lesson has no finalized sermon. Compose + finalize one before pen revision.')),
      );
      return;
    }

    setState(() => _submitting = true);
    final ownerId = context.read<AuthService>().user!.uid;
    final teacher = context.read<TeacherProfileService>().profile;
    final classProfile = context.read<ClassProfileService>().profile;
    final doctrine = context.read<DoctrinalPositionsService>().positions;
    final corpus = context.read<VoiceCorpusService>().items;
    final annotationSvc = context.read<AnnotationService>();
    final lessonSvc = context.read<LessonService>();
    final messenger = ScaffoldMessenger.of(context);

    final inMemoryAnnotation = SermonAnnotation(
      ownerId: ownerId,
      lessonId: _lesson.id!,
      version: 1,
      canvasWidth: _capturedCanvasSize!.width,
      canvasHeight: _capturedCanvasSize!.height,
      strokes: List.of(_strokes),
    );

    final result = await AiPenRevisionService.reviseFromAnnotation(
      lesson: _lesson,
      annotation: inMemoryAnnotation,
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: corpus,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text('AI revision failed: ${result.error ?? "unknown"}')),
      );
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PenRevisionDiffDialog(
        original: _lesson.finalizedSermonText,
        revised: result.text ?? '',
      ),
    );
    if (accepted != true || !mounted) return;

    // Persist: save the annotation as a new version + update lesson text.
    await annotationSvc.saveNewVersion(inMemoryAnnotation);
    final updatedLesson =
        _lesson.copyWith(finalizedSermonText: result.text ?? '');
    final ok = await lessonSvc.updateLesson(updatedLesson);
    if (!mounted) return;
    if (ok) {
      setState(() => _lesson = updatedLesson);
      messenger.showSnackBar(
        const SnackBar(
            content:
                Text('Sermon updated. Annotations saved as a new version.')),
      );
      Navigator.of(context).pop(updatedLesson);
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to save the revised sermon.')),
      );
    }
  }

  Future<void> _showVersions() async {
    final svc = context.read<AnnotationService>();
    final versions = svc.versionsFor(_lesson.id!);
    if (versions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No saved versions yet.')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text('Annotation Versions',
                      style: Theme.of(ctx).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: versions.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final v = versions[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.2),
                      child: Text('v${v.version}',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                    title: Text(
                      DateFormat.yMMMd().add_jm().format(v.createdAt),
                    ),
                    subtitle: Text(
                        '${v.strokeCount} strokes · ${v.pointCount} points'),
                    trailing: IconButton(
                      icon: const Icon(Icons.download),
                      tooltip: 'Load this version',
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        setState(() {
                          _strokes
                            ..clear()
                            ..addAll(v.strokes);
                          _capturedCanvasSize =
                              Size(v.canvasWidth, v.canvasHeight);
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Loaded version ${v.version}')),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = _lesson;
    final hasText = lesson.finalizedSermonText.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text('Annotate: ${lesson.title}'),
        actions: [
          ToggleButtons(
            isSelected: [_penMode, !_penMode],
            onPressed: (i) => setState(() => _penMode = i == 0),
            borderRadius: BorderRadius.circular(8),
            constraints: const BoxConstraints(minHeight: 36, minWidth: 60),
            children: const [
              Tooltip(message: 'Pen mode', child: Icon(Icons.edit)),
              Tooltip(
                  message: 'Scroll mode (no drawing)',
                  child: Icon(Icons.swipe_vertical)),
            ],
          ),
          const SizedBox(width: 12),
          IconButton(
            tooltip: 'Undo last stroke',
            icon: const Icon(Icons.undo),
            onPressed: _strokes.isEmpty ? null : _undo,
          ),
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_outline),
            onPressed: _strokes.isEmpty ? null : _clear,
          ),
          IconButton(
            tooltip: 'Versions',
            icon: const Icon(Icons.history),
            onPressed: _showVersions,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _Toolbar(
            currentColor: _inkColor,
            onColor: (c) => setState(() => _inkColor = c),
          ),
        ),
      ),
      body: Stack(
        children: [
          hasText
              ? _loading
                  ? const Center(child: CircularProgressIndicator())
                  : InkCanvas(
                      text: lesson.finalizedSermonText,
                      strokes: _strokes,
                      inkColor: _inkColor,
                      penMode: _penMode,
                      onStrokeFinished: _onStrokeFinished,
                      onCanvasSizeChanged: (size) {
                        if (_capturedCanvasSize == null) {
                          _capturedCanvasSize = size;
                        } else if ((size.width - _capturedCanvasSize!.width)
                                    .abs() >
                                1 ||
                            (size.height - _capturedCanvasSize!.height).abs() >
                                1) {
                          _capturedCanvasSize = size;
                        }
                      },
                    )
              : const _NoText(),
          if (_submitting) const _SubmittingOverlay(),
        ],
      ),
      bottomNavigationBar: _AiSubmitFooter(
        submitting: _submitting,
        onSubmit: _strokes.isEmpty ? null : _submitForRevision,
      ),
    );
  }
}

class _SubmittingOverlay extends StatelessWidget {
  const _SubmittingOverlay();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: AbsorbPointer(
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.cardLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text('Sending pen edits to Claude (Opus)…',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('Vision call typically takes 30-60 seconds.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PenRevisionDiffDialog extends StatefulWidget {
  final String original;
  final String revised;
  const _PenRevisionDiffDialog({required this.original, required this.revised});

  @override
  State<_PenRevisionDiffDialog> createState() => _PenRevisionDiffDialogState();
}

class _PenRevisionDiffDialogState extends State<_PenRevisionDiffDialog> {
  bool _showDiff = true;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.draw, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'AI revised your sermon based on your pen edits',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  ToggleButtons(
                    isSelected: [_showDiff, !_showDiff],
                    onPressed: (i) => setState(() => _showDiff = i == 0),
                    borderRadius: BorderRadius.circular(8),
                    constraints:
                        const BoxConstraints(minHeight: 36, minWidth: 90),
                    children: const [
                      Tooltip(message: 'Side-by-side', child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Diff'),
                      )),
                      Tooltip(message: 'Revised only', child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('Clean'),
                      )),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _showDiff ? _diffView() : _cleanView(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Discard revision'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).pop(true),
                    icon: const Icon(Icons.check),
                    label: const Text('Accept revision'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _diffView() {
    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 720;
      if (!isWide) return _cleanView();
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _panel('Original', widget.original, false)),
          const SizedBox(width: 14),
          Expanded(child: _panel('Revised', widget.revised, true)),
        ],
      );
    });
  }

  Widget _cleanView() => _panel('Revised', widget.revised, true);

  Widget _panel(String label, String text, bool highlight) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight
              ? AppColors.primary
              : AppColors.primary.withValues(alpha: 0.2),
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 1.0,
                  )),
          const SizedBox(height: 6),
          Expanded(
            child: SingleChildScrollView(
              child: SelectableText(
                text.isEmpty ? '(empty)' : text,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final Color currentColor;
  final ValueChanged<Color> onColor;
  const _Toolbar({required this.currentColor, required this.onColor});

  static const List<Color> _colors = [
    Color(0xFFEF4444), // red
    Color(0xFFFBBF24), // yellow
    Color(0xFF60A5FA), // blue
    Color(0xFF34D399), // green
    Color(0xFFF5F5F5), // off-white
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceLight,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text('Ink color:',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 12),
          for (final c in _colors)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onColor(c),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: c == currentColor
                          ? AppColors.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NoText extends StatelessWidget {
  const _NoText();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.draw_outlined,
                color: AppColors.primary.withValues(alpha: 0.5), size: 72),
            const SizedBox(height: 16),
            Text('Nothing to annotate yet',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Compose a finalized sermon first. Then come back to mark it up by hand.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AiSubmitFooter extends StatelessWidget {
  final bool submitting;
  final VoidCallback? onSubmit;

  const _AiSubmitFooter({required this.submitting, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(
          top: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(Icons.auto_awesome,
                color: AppColors.primary.withValues(alpha: 0.7), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                onSubmit == null
                    ? 'Draw your edits, then submit to Claude vision for a revised sermon.'
                    : 'Submit your handwritten edits — Claude reads them and rewrites the sermon (Opus, ~30-60s).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            ElevatedButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.send, size: 16),
              label: Text(submitting
                  ? 'Submitting…'
                  : 'Submit for AI revision'),
            ),
          ],
        ),
      ),
    );
  }
}
