import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/lesson.dart';
import '../../../models/section.dart' as model;
import '../../../services/ai_lesson_service.dart';
import '../../../services/ai_support_doc_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/class_profile_service.dart';
import '../../../services/doctrinal_positions_service.dart';
import '../../../services/lesson_pdf_exporter.dart';
import '../../../services/lesson_service.dart';
import '../../../services/series_service.dart';
import '../../../services/teacher_profile_service.dart';
import '../../../services/voice_corpus_service.dart';
import '../../ai/screens/study_brief_screen.dart';
import '../../ai/widgets/ai_revise_dialog.dart';
import '../../annotation/screens/annotation_screen.dart';
import '../../sermon_mode/screens/sermon_mode_screen.dart';
import '../../support_docs/screens/fill_in_handout_preview_screen.dart';
import '../widgets/lesson_form_dialog.dart';

class LessonEditorScreen extends StatefulWidget {
  final Lesson lesson;
  const LessonEditorScreen({super.key, required this.lesson});

  @override
  State<LessonEditorScreen> createState() => _LessonEditorScreenState();
}

class _LessonEditorScreenState extends State<LessonEditorScreen> {
  late Lesson _lesson;
  late final TextEditingController _finalizedController;
  final List<_SectionDraft> _sections = [];
  final List<String> _pendingDeletes = [];
  bool _loadingSections = true;
  bool _saving = false;
  bool _metaDirty = false;
  bool _finalizedDirty = false;
  int? _generatingSectionIndex;
  SupportDocType? _generatingDocType;

  @override
  void initState() {
    super.initState();
    _lesson = widget.lesson;
    _finalizedController =
        TextEditingController(text: _lesson.finalizedSermonText);
    _finalizedController.addListener(() {
      if (_finalizedController.text != _lesson.finalizedSermonText &&
          !_finalizedDirty) {
        setState(() => _finalizedDirty = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSections());
  }

  Future<void> _loadSections() async {
    final ownerId = context.read<AuthService>().user!.uid;
    final loaded = await context.read<LessonService>()
        .loadSections(ownerId, _lesson.id!);
    if (!mounted) return;
    setState(() {
      _sections.clear();
      _sections.addAll(loaded.map((s) => _SectionDraft.fromExisting(s)));
      _loadingSections = false;
    });
  }

  @override
  void dispose() {
    _finalizedController.dispose();
    for (final draft in _sections) {
      draft.dispose();
    }
    super.dispose();
  }

  bool get _hasUnsavedChanges =>
      _metaDirty ||
      _finalizedDirty ||
      _pendingDeletes.isNotEmpty ||
      _sections.any((s) => s.isDirty || s.isNew);

  Future<bool> _confirmDiscardIfDirty() async {
    if (!_hasUnsavedChanges) return true;
    final keep = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unsaved changes'),
        content: const Text('Leave without saving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return keep == true;
  }

  Future<void> _editMetadata() async {
    final ownerId = context.read<AuthService>().user!.uid;
    final updated = await showDialog<Lesson>(
      context: context,
      builder: (_) => LessonFormDialog(
        initial: _lesson,
        ownerId: ownerId,
        seriesId: _lesson.seriesId,
      ),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _lesson = updated;
      _metaDirty = true;
    });
  }

  void _addSection() {
    final ownerId = context.read<AuthService>().user!.uid;
    setState(() {
      _sections.add(_SectionDraft.fresh(
        ownerId: ownerId,
        lessonId: _lesson.id!,
        order: _sections.length,
      ));
    });
  }

  void _deleteSection(int index) {
    final draft = _sections[index];
    if (draft.original?.id != null) {
      _pendingDeletes.add(draft.original!.id!);
    }
    setState(() => _sections.removeAt(index));
  }

  void _moveSection(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _sections.length) return;
    setState(() {
      final item = _sections.removeAt(index);
      _sections.insert(newIndex, item);
      // Mark all sections dirty since order field shifts.
      for (final s in _sections) {
        s.markDirty();
      }
    });
  }

  void _composeFinalizedFromSections() {
    final buffer = StringBuffer();
    for (var i = 0; i < _sections.length; i++) {
      final s = _sections[i];
      final title = s.titleController.text.trim();
      final content = s.contentController.text.trim();
      if (title.isEmpty && content.isEmpty) continue;
      if (title.isNotEmpty) {
        buffer.writeln('## ${i + 1}. $title');
        buffer.writeln();
      }
      if (content.isNotEmpty) {
        buffer.writeln(content);
        buffer.writeln();
      }
    }
    _finalizedController.text = buffer.toString().trim();
    setState(() => _finalizedDirty = true);
  }

  Future<void> _toggleFinalized() async {
    final svc = context.read<LessonService>();
    final next = _lesson.copyWith(isFinalized: !_lesson.isFinalized);
    final ok = await svc.updateLesson(next);
    if (!mounted) return;
    if (ok) {
      setState(() => _lesson = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(next.isFinalized
              ? 'Lesson marked finalized'
              : 'Lesson unmarked'),
        ),
      );
    }
  }

  Future<void> _exportPdf() async {
    final seriesSvc = context.read<SeriesService>();
    final series =
        seriesSvc.series.where((s) => s.id == _lesson.seriesId).toList();
    final seriesTitle = series.isEmpty ? null : series.first.title;
    final messenger = ScaffoldMessenger.of(context);

    // Snapshot sections from the live drafts so the PDF reflects exactly
    // what the teacher sees right now (no need to save first).
    final sections = <model.Section>[
      for (var i = 0; i < _sections.length; i++)
        model.Section(
          ownerId: _sections[i].ownerId,
          lessonId: _sections[i].lessonId,
          order: i,
          title: _sections[i].titleController.text,
          content: _sections[i].contentController.text,
          speakerNotes: _sections[i].notesController.text,
        ),
    ];

    try {
      final bytes = await LessonPdfExporter.export(
        lesson: _lesson,
        sections: sections,
        seriesTitle: seriesTitle,
      );
      if (!mounted) return;
      await Printing.sharePdf(bytes: bytes, filename: '${_lesson.title}.pdf');
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  Future<void> _deleteLesson() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${_lesson.title}"?'),
        content: const Text(
            'Lesson and any saved sections will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final svc = context.read<LessonService>();
    // Best-effort delete of sections, then lesson.
    for (final draft in _sections) {
      if (draft.original?.id != null) {
        await svc.deleteSection(draft.original!.id!);
      }
    }
    final removed = await svc.deleteLesson(_lesson.seriesId, _lesson.id!);
    if (removed && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveAll() async {
    setState(() => _saving = true);
    final svc = context.read<LessonService>();
    bool anyFailure = false;

    if (_metaDirty || _finalizedDirty) {
      final next = _lesson.copyWith(
        finalizedSermonText: _finalizedController.text,
      );
      final ok = await svc.updateLesson(next);
      if (ok) {
        _lesson = next;
        _metaDirty = false;
        _finalizedDirty = false;
      } else {
        anyFailure = true;
      }
    }

    for (final id in _pendingDeletes) {
      final ok = await svc.deleteSection(id);
      if (!ok) anyFailure = true;
    }
    _pendingDeletes.clear();

    for (var i = 0; i < _sections.length; i++) {
      final draft = _sections[i];
      if (!draft.isDirty && !draft.isNew) continue;
      final section = draft.toSection(order: i);
      if (draft.isNew) {
        final id = await svc.createSection(section);
        if (id == null) {
          anyFailure = true;
        } else {
          draft.adoptSavedId(id);
        }
      } else {
        final ok = await svc.updateSection(section);
        if (!ok) anyFailure = true;
        draft.markClean();
      }
    }

    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(anyFailure ? 'Some changes failed to save' : 'Saved')),
    );
  }

  // ---- AI helpers ----

  Future<void> _aiGenerateSection(int index) async {
    final draft = _sections[index];
    if (draft.contentController.text.trim().isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Replace existing content?'),
          content: const Text(
              'AI generation will replace the current section content. The AI sees your existing draft and your other sections as context.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _generatingSectionIndex = index);
    final teacher = context.read<TeacherProfileService>().profile;
    final classProfile = context.read<ClassProfileService>().profile;
    final doctrine = context.read<DoctrinalPositionsService>().positions;
    final corpus = context.read<VoiceCorpusService>().items;
    final seriesList = context.read<SeriesService>().series;
    final series = seriesList
        .where((s) => s.id == _lesson.seriesId)
        .cast<dynamic>()
        .followedBy([null]).first;
    final messenger = ScaffoldMessenger.of(context);

    final sectionForCall = draft.toSection(order: index);
    final others = <model.Section>[];
    for (var i = 0; i < _sections.length; i++) {
      if (i != index) others.add(_sections[i].toSection(order: i));
    }

    final result = await AiLessonService.generateSection(
      lesson: _lesson,
      section: sectionForCall,
      otherSections: others,
      seriesTitle: series?.title,
      seriesDescription: series?.description,
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: corpus,
    );
    if (!mounted) return;
    setState(() => _generatingSectionIndex = null);
    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(content: Text('Generate failed: ${result.error ?? "unknown"}')),
      );
      return;
    }
    setState(() {
      draft.contentController.text = result.text ?? '';
      // Marking dirty happens via the controller listener.
    });
  }

  Future<void> _aiReviseSection(int index) async {
    final draft = _sections[index];
    final revised = await showDialog<String>(
      context: context,
      builder: (_) => AiReviseDialog(
        originalText: draft.contentController.text,
        label: 'this section',
      ),
    );
    if (revised != null) {
      setState(() => draft.contentController.text = revised);
    }
  }

  Future<void> _aiReviseFinalized() async {
    final revised = await showDialog<String>(
      context: context,
      builder: (_) => AiReviseDialog(
        originalText: _finalizedController.text,
        label: 'the finalized sermon',
      ),
    );
    if (revised != null) {
      setState(() {
        _finalizedController.text = revised;
        _finalizedDirty = true;
      });
    }
  }

  void _openStudyBrief() {
    final seriesList = context.read<SeriesService>().series;
    final series = seriesList
        .where((s) => s.id == _lesson.seriesId)
        .cast<dynamic>()
        .followedBy([null]).first;
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => StudyBriefScreen(
        lesson: _lesson,
        seriesTitle: series?.title,
        seriesDescription: series?.description,
      ),
    ));
  }

  Future<void> _generateSupportDoc(SupportDocType type) async {
    setState(() => _generatingDocType = type);
    final teacher = context.read<TeacherProfileService>().profile;
    final classProfile = context.read<ClassProfileService>().profile;
    final doctrine = context.read<DoctrinalPositionsService>().positions;
    final corpus = context.read<VoiceCorpusService>().items;
    final seriesList = context.read<SeriesService>().series;
    final series = seriesList
        .where((s) => s.id == _lesson.seriesId)
        .cast<dynamic>()
        .followedBy([null]).first;
    final messenger = ScaffoldMessenger.of(context);

    final sections = <model.Section>[];
    for (var i = 0; i < _sections.length; i++) {
      sections.add(_sections[i].toSection(order: i));
    }

    final isFillIn = type == SupportDocType.fillInHandout;
    final result = await AiSupportDocService.generate(
      type: type,
      lesson: _lesson,
      sections: sections,
      seriesTitle: series?.title,
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: corpus,
      renderPdfDirectly: !isFillIn,
    );
    if (!mounted) return;
    setState(() => _generatingDocType = null);
    if (!result.success) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                '${type.label} failed: ${result.error ?? "unknown"}')),
      );
      return;
    }

    if (isFillIn) {
      // Route through the preview screen so the user can toggle which words
      // are blanks before the PDF is generated.
      if (result.data == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Fill-in handout: AI returned no data.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FillInHandoutPreviewScreen(
            lesson: _lesson,
            seriesTitle: series?.title,
            data: result.data!,
          ),
        ),
      );
      return;
    }

    if (result.pdfBytes == null) {
      messenger.showSnackBar(
        SnackBar(
            content: Text(
                '${type.label}: PDF render returned no bytes.')),
      );
      return;
    }
    await Printing.layoutPdf(
      onLayout: (_) async => result.pdfBytes!,
      name: '${type.label} - ${_lesson.title}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscardIfDirty() && mounted) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_lesson.title, overflow: TextOverflow.ellipsis),
          actions: [
            if (_hasUnsavedChanges)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: TextButton.icon(
                  onPressed: _saving ? null : _saveAll,
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
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                switch (v) {
                  case 'edit':
                    _editMetadata();
                    break;
                  case 'finalize':
                    _toggleFinalized();
                    break;
                  case 'export':
                    _exportPdf();
                    break;
                  case 'delete':
                    _deleteLesson();
                    break;
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                    value: 'edit', child: Text('Edit metadata')),
                PopupMenuItem(
                  value: 'finalize',
                  child: Text(_lesson.isFinalized
                      ? 'Mark as draft'
                      : 'Mark as finalized'),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'export',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Export as PDF'),
                    dense: true,
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'delete', child: Text('Delete lesson')),
              ],
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _LessonMetadataHeader(
                      lesson: _lesson,
                      onEdit: _editMetadata,
                      onSermonMode: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SermonModeScreen(lesson: _lesson),
                        ));
                      },
                      onAnnotate: () async {
                        final updated = await Navigator.of(context).push<Lesson>(
                          MaterialPageRoute(
                            builder: (_) => AnnotationScreen(lesson: _lesson),
                          ),
                        );
                        if (updated != null && mounted) {
                          setState(() {
                            _lesson = updated;
                            _finalizedController.text =
                                updated.finalizedSermonText;
                            _finalizedDirty = false;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),
                    _SectionListHeader(
                      count: _sections.length,
                      onAdd: _addSection,
                    ),
                    const SizedBox(height: 12),
                    if (_loadingSections)
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_sections.isEmpty)
                      _EmptySections(onAdd: _addSection)
                    else
                      Column(
                        children: [
                          for (var i = 0; i < _sections.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _SectionCard(
                                draft: _sections[i],
                                index: i,
                                total: _sections.length,
                                generating: _generatingSectionIndex == i,
                                onDelete: () => _deleteSection(i),
                                onMoveUp: () => _moveSection(i, -1),
                                onMoveDown: () => _moveSection(i, 1),
                                onGenerate: () => _aiGenerateSection(i),
                                onRevise: () => _aiReviseSection(i),
                              ),
                            ),
                        ],
                      ),
                    const SizedBox(height: 24),
                    _FinalizedSermonCard(
                      controller: _finalizedController,
                      isFinalized: _lesson.isFinalized,
                      onCompose: _composeFinalizedFromSections,
                      onToggleFinalized: _toggleFinalized,
                      onRevise: _aiReviseFinalized,
                    ),
                    const SizedBox(height: 24),
                    _AiActions(
                      onStudyBrief: _openStudyBrief,
                      onSupportDoc: _generateSupportDoc,
                      generatingType: _generatingDocType,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ----- Local draft state for sections -----

class _SectionDraft {
  final String ownerId;
  final String lessonId;
  model.Section? original;
  final TextEditingController titleController;
  final TextEditingController contentController;
  final TextEditingController notesController;
  bool _dirty;

  _SectionDraft._({
    required this.ownerId,
    required this.lessonId,
    required this.original,
    required this.titleController,
    required this.contentController,
    required this.notesController,
    bool dirty = false,
  }) : _dirty = dirty {
    titleController.addListener(markDirty);
    contentController.addListener(markDirty);
    notesController.addListener(markDirty);
  }

  factory _SectionDraft.fromExisting(model.Section s) => _SectionDraft._(
        ownerId: s.ownerId,
        lessonId: s.lessonId,
        original: s,
        titleController: TextEditingController(text: s.title),
        contentController: TextEditingController(text: s.content),
        notesController: TextEditingController(text: s.speakerNotes),
      );

  factory _SectionDraft.fresh({
    required String ownerId,
    required String lessonId,
    required int order,
  }) =>
      _SectionDraft._(
        ownerId: ownerId,
        lessonId: lessonId,
        original: null,
        titleController: TextEditingController(),
        contentController: TextEditingController(),
        notesController: TextEditingController(),
        dirty: true,
      );

  bool get isNew => original == null;
  bool get isDirty => _dirty;

  void markDirty() {
    if (!_dirty) {
      _dirty = true;
    }
  }

  void markClean() {
    _dirty = false;
  }

  void adoptSavedId(String id) {
    original = model.Section(
      id: id,
      ownerId: ownerId,
      lessonId: lessonId,
      order: 0,
      title: titleController.text,
      content: contentController.text,
      speakerNotes: notesController.text,
    );
    _dirty = false;
  }

  model.Section toSection({required int order}) {
    return model.Section(
      id: original?.id,
      ownerId: ownerId,
      lessonId: lessonId,
      order: order,
      title: titleController.text.trim(),
      content: contentController.text,
      speakerNotes: notesController.text,
    );
  }

  void dispose() {
    titleController.dispose();
    contentController.dispose();
    notesController.dispose();
  }
}

// ----- UI bits -----

class _LessonMetadataHeader extends StatelessWidget {
  final Lesson lesson;
  final VoidCallback onEdit;
  final VoidCallback onSermonMode;
  final VoidCallback onAnnotate;
  const _LessonMetadataHeader({
    required this.lesson,
    required this.onEdit,
    required this.onSermonMode,
    required this.onAnnotate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(lesson.title,
                    style: Theme.of(context).textTheme.headlineSmall),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit metadata',
              ),
            ],
          ),
          if (lesson.bigIdea.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(lesson.bigIdea,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                    )),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (lesson.scriptureReference.isNotEmpty)
                _MetaChip(
                  icon: Icons.menu_book_outlined,
                  text: lesson.scriptureReference,
                ),
              _MetaChip(
                icon: Icons.timer_outlined,
                text: '${lesson.targetDurationMinutes} min target',
              ),
              if (lesson.isFinalized)
                _MetaChip(
                  icon: Icons.check_circle,
                  text: 'Finalized',
                  color: AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: onSermonMode,
                icon: const Icon(Icons.campaign),
                label: const Text('Sermon Mode'),
              ),
              OutlinedButton.icon(
                onPressed: onAnnotate,
                icon: const Icon(Icons.draw),
                label: const Text('Annotate (Pen)'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const _MetaChip({required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: c, size: 16),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SectionListHeader extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;
  const _SectionListHeader({required this.count, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('Sections ($count)',
            style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Add Section'),
        ),
      ],
    );
  }
}

class _EmptySections extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptySections({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: AppDecorations.premiumCard,
      child: Column(
        children: [
          Icon(Icons.view_list_outlined,
              size: 48, color: AppColors.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 10),
          Text('No sections yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Common patterns: Hook → Word study → Cross-references → Application → Closing.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add first section'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatefulWidget {
  final _SectionDraft draft;
  final int index;
  final int total;
  final bool generating;
  final VoidCallback onDelete;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onGenerate;
  final VoidCallback onRevise;

  const _SectionCard({
    required this.draft,
    required this.index,
    required this.total,
    required this.generating,
    required this.onDelete,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onGenerate,
    required this.onRevise,
  });

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _showNotes = true;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.premiumCard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        AppColors.primary.withValues(alpha: 0.18),
                    child: Text('${widget.index + 1}',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: widget.draft.titleController,
                      style: Theme.of(context).textTheme.titleMedium,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'Section title (e.g. Hook, Word Study)',
                        isCollapsed: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 6),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Move up',
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: widget.index == 0 ? null : widget.onMoveUp,
                  ),
                  IconButton(
                    tooltip: 'Move down',
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: widget.index == widget.total - 1
                        ? null
                        : widget.onMoveDown,
                  ),
                  IconButton(
                    tooltip: 'Delete section',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: widget.onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _contentField(context)),
                    const SizedBox(width: 14),
                    Expanded(child: _notesField(context)),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _contentField(context),
                    const SizedBox(height: 12),
                    if (_showNotes) _notesField(context),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () =>
                            setState(() => _showNotes = !_showNotes),
                        icon: Icon(_showNotes
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down),
                        label: Text(_showNotes
                            ? 'Hide speaker notes'
                            : 'Show speaker notes'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              _AiSectionActions(
                generating: widget.generating,
                hasContent: widget.draft.contentController.text.trim().isNotEmpty,
                onGenerate: widget.onGenerate,
                onRevise: widget.onRevise,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _contentField(BuildContext context) {
    return _LabeledField(
      label: 'Content',
      hint: 'What you teach in this section...',
      controller: widget.draft.contentController,
    );
  }

  Widget _notesField(BuildContext context) {
    return _LabeledField(
      label: 'Speaker Notes',
      hint: 'Reminders, cues, illustrations — hidden in Sermon Mode.',
      controller: widget.draft.notesController,
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  const _LabeledField({
    required this.label,
    required this.hint,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    letterSpacing: 1.0,
                  )),
        ),
        TextField(
          controller: controller,
          maxLines: null,
          minLines: 4,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            hintText: hint,
            alignLabelWithHint: true,
            isDense: true,
          ),
        ),
      ],
    );
  }
}

class _AiSectionActions extends StatelessWidget {
  final bool generating;
  final bool hasContent;
  final VoidCallback onGenerate;
  final VoidCallback onRevise;

  const _AiSectionActions({
    required this.generating,
    required this.hasContent,
    required this.onGenerate,
    required this.onRevise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              size: 16, color: AppColors.primary.withValues(alpha: 0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hasContent
                  ? 'Generate replaces this section. Ask AI revises in place.'
                  : 'Generate this section from your lesson context + voice.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          OutlinedButton.icon(
            onPressed: hasContent && !generating ? onRevise : null,
            icon: const Icon(Icons.edit_note, size: 16),
            label: const Text('Ask AI'),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: generating ? null : onGenerate,
            icon: generating
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.auto_awesome, size: 16),
            label: Text(generating ? 'Generating…' : 'Generate'),
          ),
        ],
      ),
    );
  }
}

class _FinalizedSermonCard extends StatefulWidget {
  final TextEditingController controller;
  final bool isFinalized;
  final VoidCallback onCompose;
  final VoidCallback onToggleFinalized;
  final VoidCallback onRevise;

  const _FinalizedSermonCard({
    required this.controller,
    required this.isFinalized,
    required this.onCompose,
    required this.onToggleFinalized,
    required this.onRevise,
  });

  @override
  State<_FinalizedSermonCard> createState() => _FinalizedSermonCardState();
}

class _FinalizedSermonCardState extends State<_FinalizedSermonCard> {
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isFinalized || widget.controller.text.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('Finalized Sermon',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (widget.isFinalized)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('Ready for Sermon Mode',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                          )),
                ),
              IconButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.onCompose,
                  icon: const Icon(Icons.merge_type),
                  label: const Text('Compose from sections'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.controller.text.trim().isEmpty
                      ? null
                      : widget.onRevise,
                  icon: const Icon(Icons.edit_note),
                  label: const Text('Ask AI to change'),
                ),
                OutlinedButton.icon(
                  onPressed: widget.onToggleFinalized,
                  icon: Icon(widget.isFinalized
                      ? Icons.unpublished_outlined
                      : Icons.task_alt),
                  label: Text(widget.isFinalized
                      ? 'Mark as draft'
                      : 'Mark finalized'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: widget.controller,
              maxLines: null,
              minLines: 8,
              textAlignVertical: TextAlignVertical.top,
              decoration: const InputDecoration(
                hintText:
                    'The polished sermon text used in Sermon Mode. Compose from sections to start, then refine.',
                isDense: true,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AiActions extends StatelessWidget {
  final VoidCallback onStudyBrief;
  final void Function(SupportDocType type) onSupportDoc;
  final SupportDocType? generatingType;

  const _AiActions({
    required this.onStudyBrief,
    required this.onSupportDoc,
    required this.generatingType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary),
              const SizedBox(width: 10),
              Text('AI Research & Support Docs',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: onStudyBrief,
                icon: const Icon(Icons.science_outlined, size: 18),
                label: const Text('Study Brief + Deep Dive'),
              ),
              for (final type in SupportDocType.values)
                _SupportDocButton(
                  type: type,
                  generating: generatingType == type,
                  disabledOther: generatingType != null && generatingType != type,
                  onPressed: () => onSupportDoc(type),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Outputs are AI-generated drafts — you are the author. Edit anything in place or hit "Ask AI to change…" to refine.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SupportDocButton extends StatelessWidget {
  final SupportDocType type;
  final bool generating;
  final bool disabledOther;
  final VoidCallback onPressed;

  const _SupportDocButton({
    required this.type,
    required this.generating,
    required this.disabledOther,
    required this.onPressed,
  });

  IconData get _icon {
    switch (type) {
      case SupportDocType.slides:
        return Icons.slideshow_outlined;
      case SupportDocType.handout:
        return Icons.description_outlined;
      case SupportDocType.fillInHandout:
        return Icons.edit_note;
      case SupportDocType.outline:
        return Icons.list_alt;
      case SupportDocType.discussionGuide:
        return Icons.forum_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: (generating || disabledOther) ? null : onPressed,
      icon: generating
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(_icon, size: 18),
      label: Text(generating ? '${type.label} (PDF)…' : '${type.label} (PDF)'),
    );
  }
}
