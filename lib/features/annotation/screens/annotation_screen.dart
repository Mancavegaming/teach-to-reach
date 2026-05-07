import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/lesson.dart';
import '../../../models/sermon_annotation.dart';
import '../../../services/annotation_service.dart';
import '../../../services/auth_service.dart';
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
  Size? _capturedCanvasSize;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  Future<void> _loadInitial() async {
    final ownerId = context.read<AuthService>().user!.uid;
    final svc = context.read<AnnotationService>();
    await svc.loadForLesson(ownerId, widget.lesson.id!);
    final latest = svc.latestFor(widget.lesson.id!);
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
      lessonId: widget.lesson.id!,
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

  Future<void> _showVersions() async {
    final svc = context.read<AnnotationService>();
    final versions = svc.versionsFor(widget.lesson.id!);
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
    final lesson = widget.lesson;
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
      body: hasText
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
                      // Window resized; remember the latest size for next save.
                      _capturedCanvasSize = size;
                    }
                  },
                )
          : const _NoText(),
      bottomNavigationBar: const _AiSubmitFooter(),
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
  const _AiSubmitFooter();

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
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              color: AppColors.primary.withValues(alpha: 0.7), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Save your annotations, then submit them for AI revision (Phase 4).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Tooltip(
            message: 'AI revision arrives in Phase 4',
            child: ElevatedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Submit for AI revision'),
            ),
          ),
        ],
      ),
    );
  }
}
