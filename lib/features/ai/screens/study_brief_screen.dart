import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/lesson.dart';
import '../../../models/study_brief.dart';
import '../../../services/ai_lesson_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/class_profile_service.dart';
import '../../../services/doctrinal_positions_service.dart';
import '../../../services/lesson_service.dart';
import '../../../services/teacher_profile_service.dart';
import '../../../services/voice_corpus_service.dart';
import '../widgets/ai_revise_dialog.dart';

class StudyBriefScreen extends StatefulWidget {
  final Lesson lesson;
  final String? seriesTitle;
  final String? seriesDescription;

  const StudyBriefScreen({
    super.key,
    required this.lesson,
    this.seriesTitle,
    this.seriesDescription,
  });

  @override
  State<StudyBriefScreen> createState() => _StudyBriefScreenState();
}

class _StudyBriefScreenState extends State<StudyBriefScreen> {
  StudyBrief? _brief;
  bool _loading = true;
  bool _saving = false;
  bool _generatingBrief = false;
  bool _generatingDeepDive = false;

  late final TextEditingController _briefController;
  late final TextEditingController _eventController;
  late final TextEditingController _authorshipController;

  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _briefController = TextEditingController()..addListener(_onChange);
    _eventController = TextEditingController()..addListener(_onChange);
    _authorshipController = TextEditingController()..addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _onChange() {
    if (_dirty) return;
    setState(() => _dirty = true);
  }

  Future<void> _load() async {
    final ownerId = context.read<AuthService>().user!.uid;
    final svc = context.read<LessonService>();
    final brief = await svc.loadBriefForLesson(ownerId, widget.lesson.id!);
    if (!mounted) return;
    setState(() {
      _brief = brief ??
          StudyBrief(ownerId: ownerId, lessonId: widget.lesson.id!);
      _briefController.text = _brief!.content;
      _eventController.text = _brief!.eventHorizon;
      _authorshipController.text = _brief!.authorshipHorizon;
      _dirty = false;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _briefController.dispose();
    _eventController.dispose();
    _authorshipController.dispose();
    super.dispose();
  }

  Future<void> _generateBrief() async {
    final teacher = context.read<TeacherProfileService>().profile;
    final classProfile = context.read<ClassProfileService>().profile;
    final doctrine = context.read<DoctrinalPositionsService>().positions;
    final corpus = context.read<VoiceCorpusService>().items;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generatingBrief = true);
    final result = await AiLessonService.generateStudyBrief(
      lesson: widget.lesson,
      seriesTitle: widget.seriesTitle,
      seriesDescription: widget.seriesDescription,
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: corpus,
    );
    if (!mounted) return;
    setState(() => _generatingBrief = false);
    if (!result.success) {
      messenger.showSnackBar(SnackBar(
          content: Text('Generate failed: ${result.error ?? "unknown"}')));
      return;
    }
    setState(() {
      _briefController.text = result.text ?? '';
      _dirty = true;
    });
  }

  Future<void> _generateDeepDive() async {
    final teacher = context.read<TeacherProfileService>().profile;
    final classProfile = context.read<ClassProfileService>().profile;
    final doctrine = context.read<DoctrinalPositionsService>().positions;
    final corpus = context.read<VoiceCorpusService>().items;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _generatingDeepDive = true);
    final result = await AiLessonService.generateDeepDive(
      lesson: widget.lesson,
      seriesTitle: widget.seriesTitle,
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: corpus,
    );
    if (!mounted) return;
    setState(() => _generatingDeepDive = false);
    if (!result.success) {
      messenger.showSnackBar(SnackBar(
          content:
              Text('Deep Dive failed: ${result.error ?? "unknown"}')));
      return;
    }
    setState(() {
      _eventController.text = result.eventHorizon ?? '';
      _authorshipController.text = result.authorshipHorizon ?? '';
      _dirty = true;
    });
  }

  Future<void> _reviseField(TextEditingController controller, String label) async {
    final revised = await showDialog<String>(
      context: context,
      builder: (_) => AiReviseDialog(
        originalText: controller.text,
        label: label,
      ),
    );
    if (revised != null) {
      setState(() {
        controller.text = revised;
        _dirty = true;
      });
    }
  }

  Future<void> _save() async {
    if (_brief == null) return;
    setState(() => _saving = true);
    final svc = context.read<LessonService>();
    final messenger = ScaffoldMessenger.of(context);
    final updated = _brief!.copyWith(
      content: _briefController.text,
      eventHorizon: _eventController.text,
      authorshipHorizon: _authorshipController.text,
    );
    final id = await svc.saveBrief(updated);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (id != null) {
        _brief = StudyBrief(
          id: id,
          ownerId: updated.ownerId,
          lessonId: updated.lessonId,
          content: updated.content,
          eventHorizon: updated.eventHorizon,
          authorshipHorizon: updated.authorshipHorizon,
          model: updated.model,
        );
        _dirty = false;
      }
    });
    messenger.showSnackBar(
      SnackBar(content: Text(id == null ? 'Save failed' : 'Study brief saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    return Scaffold(
      appBar: AppBar(
        title: Text('Study Brief: ${lesson.title}',
            overflow: TextOverflow.ellipsis),
        actions: [
          if (_dirty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
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
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 60),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LessonContextCard(lesson: lesson),
                        const SizedBox(height: 20),
                        _AiSection(
                          title: 'Brief Content',
                          subtitle:
                              'Comprehensive research notes — overview, word study, cross-references, themes, pitfalls, application angles.',
                          icon: Icons.science_outlined,
                          controller: _briefController,
                          generating: _generatingBrief,
                          onGenerate: _generateBrief,
                          onRevise: () => _reviseField(
                              _briefController, 'the brief'),
                        ),
                        const SizedBox(height: 20),
                        _DeepDiveHeader(
                          generating: _generatingDeepDive,
                          onGenerate: _generateDeepDive,
                        ),
                        const SizedBox(height: 12),
                        _AiSection(
                          title: 'Event Horizon',
                          subtitle:
                              'What was happening when the events the passage describes took place.',
                          icon: Icons.public,
                          controller: _eventController,
                          generating: _generatingDeepDive,
                          showGenerate: false,
                          onGenerate: _generateDeepDive,
                          onRevise: () => _reviseField(
                              _eventController, 'the event horizon'),
                        ),
                        const SizedBox(height: 20),
                        _AiSection(
                          title: 'Authorship Horizon',
                          subtitle:
                              'What was happening when the text was written, who the author and audience were.',
                          icon: Icons.history_edu,
                          controller: _authorshipController,
                          generating: _generatingDeepDive,
                          showGenerate: false,
                          onGenerate: _generateDeepDive,
                          onRevise: () => _reviseField(
                              _authorshipController, 'the authorship horizon'),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _LessonContextCard extends StatelessWidget {
  final Lesson lesson;
  const _LessonContextCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lesson.title,
              style: Theme.of(context).textTheme.titleLarge),
          if (lesson.scriptureReference.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(lesson.scriptureReference,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.primary,
                      )),
            ),
          if (lesson.bigIdea.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(lesson.bigIdea,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      )),
            ),
        ],
      ),
    );
  }
}

class _DeepDiveHeader extends StatelessWidget {
  final bool generating;
  final VoidCallback onGenerate;
  const _DeepDiveHeader({required this.generating, required this.onGenerate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.secondary.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.travel_explore, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Deep Dive — Two Horizons',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Generates Event horizon (when the events happened) AND Authorship horizon (when the text was written) as a single Opus call.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: generating ? null : onGenerate,
            icon: generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(generating ? 'Generating…' : 'Generate Deep Dive'),
          ),
        ],
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final TextEditingController controller;
  final bool generating;
  final bool showGenerate;
  final VoidCallback onGenerate;
  final VoidCallback onRevise;

  const _AiSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.controller,
    required this.generating,
    required this.onGenerate,
    required this.onRevise,
    this.showGenerate = true,
  });

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
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(subtitle,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              if (showGenerate)
                ElevatedButton.icon(
                  onPressed: generating ? null : onGenerate,
                  icon: generating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(generating ? 'Generating…' : 'Generate'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: controller.text.trim().isEmpty ? null : onRevise,
                icon: const Icon(Icons.edit_note),
                label: const Text('Ask AI'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            maxLines: null,
            minLines: 6,
            textAlignVertical: TextAlignVertical.top,
            decoration: const InputDecoration(
              hintText:
                  'Generate above, paste, or write — content is markdown.',
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }
}
