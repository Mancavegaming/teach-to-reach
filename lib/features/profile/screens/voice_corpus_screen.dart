import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/voice_corpus_item.dart';
import '../../../services/auth_service.dart';
import '../../../services/voice_corpus_service.dart';

class VoiceCorpusScreen extends StatelessWidget {
  const VoiceCorpusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = context.watch<VoiceCorpusService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Voice Corpus')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editItem(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Add'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _IntroCard(
                    title: 'Past sermons, lessons, devotionals, blog posts',
                    description:
                        'The AI reads these as cached system context to learn your voice. Paste content directly here. File upload arrives in a later phase.',
                  ),
                  const SizedBox(height: 12),
                  _StatsBar(svc: svc),
                  const SizedBox(height: 16),
                  Expanded(
                    child: svc.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : svc.items.isEmpty
                            ? _EmptyState(
                                onAdd: () => _editItem(context, null))
                            : ListView.separated(
                                itemCount: svc.items.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, idx) {
                                  final item = svc.items[idx];
                                  return _CorpusTile(
                                    item: item,
                                    onTap: () => _editItem(context, item),
                                    onDelete: () =>
                                        _confirmDelete(context, item),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _editItem(BuildContext context, VoiceCorpusItem? item) async {
    final result = await showDialog<VoiceCorpusItem>(
      context: context,
      builder: (_) => _CorpusEditorDialog(initial: item),
    );
    if (result == null || !context.mounted) return;
    final svc = context.read<VoiceCorpusService>();
    if (result.id == null) {
      await svc.create(result);
    } else {
      await svc.update(result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, VoiceCorpusItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${item.title}"?'),
        content: const Text('This cannot be undone.'),
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
    if (ok == true && context.mounted) {
      await context.read<VoiceCorpusService>().delete(item.id!);
    }
  }
}

class _StatsBar extends StatelessWidget {
  final VoiceCorpusService svc;
  const _StatsBar({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardLight,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Icon(Icons.text_snippet_outlined, color: AppColors.primary),
          const SizedBox(width: 10),
          Text('${svc.items.length} items',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(width: 24),
          Icon(Icons.numbers, color: AppColors.primary),
          const SizedBox(width: 10),
          Text('${svc.totalWordCount} words',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.record_voice_over_outlined,
              color: AppColors.primary.withValues(alpha: 0.4), size: 64),
          const SizedBox(height: 16),
          Text('Your voice corpus is empty',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            width: 360,
            child: Text(
              'Paste in sermons, lessons, devotionals, or blog posts you\'ve written. '
              'The AI uses these to learn your voice.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Add first item'),
          ),
        ],
      ),
    );
  }
}

class _CorpusTile extends StatelessWidget {
  final VoiceCorpusItem item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _CorpusTile({
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: AppDecorations.premiumCard,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(_iconFor(item.contentType), color: AppColors.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: Theme.of(context).textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.contentType.displayName} · ${item.wordCount} words',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(VoiceContentType type) {
    switch (type) {
      case VoiceContentType.sermon:
        return Icons.campaign_outlined;
      case VoiceContentType.lesson:
        return Icons.school_outlined;
      case VoiceContentType.devotional:
        return Icons.self_improvement_outlined;
      case VoiceContentType.blogPost:
        return Icons.article_outlined;
      case VoiceContentType.other:
        return Icons.text_snippet_outlined;
    }
  }
}

class _IntroCard extends StatelessWidget {
  final String title;
  final String description;
  const _IntroCard({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.premiumCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _CorpusEditorDialog extends StatefulWidget {
  final VoiceCorpusItem? initial;
  const _CorpusEditorDialog({required this.initial});

  @override
  State<_CorpusEditorDialog> createState() => _CorpusEditorDialogState();
}

class _CorpusEditorDialogState extends State<_CorpusEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;
  late VoiceContentType _type;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial?.title ?? '');
    _bodyController =
        TextEditingController(text: widget.initial?.bodyText ?? '');
    _type = widget.initial?.contentType ?? VoiceContentType.sermon;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and content are required.')),
      );
      return;
    }
    final ownerId = context.read<AuthService>().user!.uid;
    final result = (widget.initial ??
            VoiceCorpusItem(ownerId: ownerId, title: title))
        .copyWith(
      title: title,
      bodyText: body,
      contentType: _type,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.initial == null
                          ? 'Add Corpus Item'
                          : 'Edit Corpus Item',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<VoiceContentType>(
                initialValue: _type,
                decoration: const InputDecoration(
                  labelText: 'Type',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                items: [
                  for (final t in VoiceContentType.values)
                    DropdownMenuItem(value: t, child: Text(t.displayName)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TextField(
                  controller: _bodyController,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: const InputDecoration(
                    labelText: 'Content',
                    alignLabelWithHint: true,
                    hintText:
                        'Paste the full text of the sermon, lesson, or devotional here...',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
