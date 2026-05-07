import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/lesson.dart';
import '../../../models/series.dart';
import '../../../services/auth_service.dart';
import '../../../services/lesson_service.dart';
import '../../../services/series_service.dart';
import '../../lessons/screens/lesson_editor_screen.dart';
import '../../lessons/widgets/lesson_form_dialog.dart';
import '../widgets/series_form_dialog.dart';

class SeriesDetailScreen extends StatefulWidget {
  final Series series;
  const SeriesDetailScreen({super.key, required this.series});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  late Series _series;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _series = widget.series;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ownerId = context.read<AuthService>().user!.uid;
      await context.read<LessonService>().loadLessonsForSeries(
            ownerId,
            _series.id!,
          );
      if (mounted) setState(() => _loaded = true);
    });
  }

  Future<void> _editSeries() async {
    final ownerId = context.read<AuthService>().user!.uid;
    final updated = await showDialog<Series>(
      context: context,
      builder: (_) => SeriesFormDialog(initial: _series, ownerId: ownerId),
    );
    if (updated == null || !mounted) return;
    final ok = await context.read<SeriesService>().update(updated);
    if (ok && mounted) {
      setState(() => _series = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Series updated')),
      );
    }
  }

  Future<void> _deleteSeries() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${_series.title}"?'),
        content: const Text(
          'This deletes the series record. Lessons inside it remain in the database '
          'but become orphans. Consider deleting individual lessons first.',
        ),
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
    final success = await context.read<SeriesService>().delete(_series.id!);
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _newLesson() async {
    final ownerId = context.read<AuthService>().user!.uid;
    final lessonSvc = context.read<LessonService>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final created = await showDialog<Lesson>(
      context: context,
      builder: (_) => LessonFormDialog(
        ownerId: ownerId,
        seriesId: _series.id!,
      ),
    );
    if (created == null || !mounted) return;
    final id = await lessonSvc.createLesson(created);
    if (id == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to create lesson')),
      );
      return;
    }
    if (!mounted) return;
    navigator.push(MaterialPageRoute(
      builder: (_) => LessonEditorScreen(lesson: created.copyWith(id: id)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final lessons = context.watch<LessonService>().lessonsFor(_series.id!);
    return Scaffold(
      appBar: AppBar(
        title: Text(_series.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Edit series',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editSeries,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              if (v == 'delete') _deleteSeries();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'delete', child: Text('Delete series')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _newLesson,
        icon: const Icon(Icons.add),
        label: const Text('New Lesson'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SeriesMetadataCard(series: _series),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Text('Lessons',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(width: 8),
                      if (_loaded)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text('${lessons.length}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppColors.primary)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (!_loaded)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (lessons.isEmpty)
                    _EmptyLessons(onAdd: _newLesson)
                  else
                    Column(
                      children: [
                        for (final lesson in lessons)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _LessonTile(lesson: lesson),
                          ),
                      ],
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

class _SeriesMetadataCard extends StatelessWidget {
  final Series series;
  const _SeriesMetadataCard({required this.series});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppDecorations.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (series.description.isNotEmpty) ...[
            Text(series.description,
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _Chip(
                  icon: Icons.cake_outlined,
                  label: series.ageGroup),
              if (series.targetAudience.isNotEmpty)
                _Chip(
                    icon: Icons.groups_outlined,
                    label: series.targetAudience),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Chip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 16),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyLessons extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyLessons({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: AppDecorations.premiumCard,
      child: Column(
        children: [
          Icon(Icons.menu_book_outlined,
              size: 56, color: AppColors.primary.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text('No lessons yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'Start with a single lesson — give it a title, scripture reference, and big idea.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add first lesson'),
          ),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  final Lesson lesson;
  const _LessonTile({required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => LessonEditorScreen(lesson: lesson),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.premiumCard,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  lesson.isFinalized
                      ? Icons.check_circle
                      : Icons.menu_book_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            lesson.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lesson.isFinalized)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text('Finalized',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.success)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        if (lesson.scriptureReference.isNotEmpty)
                          _MetaText(
                              icon: Icons.menu_book_outlined,
                              text: lesson.scriptureReference),
                        _MetaText(
                            icon: Icons.timer_outlined,
                            text: '${lesson.targetDurationMinutes} min'),
                        _MetaText(
                          icon: Icons.update,
                          text: 'Updated ${_relativeDate(lesson.updatedAt)}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

String _relativeDate(DateTime date) {
  final diff = DateTime.now().difference(date);
  if (diff.inDays == 0) return 'today';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(date);
}
