import 'package:flutter/material.dart';

import '../../../models/lesson.dart';

class LessonFormDialog extends StatefulWidget {
  final Lesson? initial;
  final String ownerId;
  final String seriesId;

  const LessonFormDialog({
    super.key,
    this.initial,
    required this.ownerId,
    required this.seriesId,
  });

  @override
  State<LessonFormDialog> createState() => _LessonFormDialogState();
}

class _LessonFormDialogState extends State<LessonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _scriptureController;
  late final TextEditingController _bigIdeaController;
  late final TextEditingController _durationController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial?.title ?? '');
    _scriptureController =
        TextEditingController(text: widget.initial?.scriptureReference ?? '');
    _bigIdeaController =
        TextEditingController(text: widget.initial?.bigIdea ?? '');
    _durationController = TextEditingController(
        text: (widget.initial?.targetDurationMinutes ?? 30).toString());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _scriptureController.dispose();
    _bigIdeaController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final base = widget.initial ??
        Lesson(
          ownerId: widget.ownerId,
          seriesId: widget.seriesId,
          title: _titleController.text.trim(),
        );
    final result = base.copyWith(
      title: _titleController.text.trim(),
      scriptureReference: _scriptureController.text.trim(),
      bigIdea: _bigIdeaController.text.trim(),
      targetDurationMinutes:
          int.tryParse(_durationController.text.trim()) ?? 30,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isEdit ? 'Edit Lesson' : 'New Lesson',
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
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Lesson Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title required'
                      : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _scriptureController,
                  decoration: const InputDecoration(
                    labelText: 'Scripture Reference',
                    prefixIcon: Icon(Icons.menu_book_outlined),
                    hintText: 'e.g. John 3:16-21',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _bigIdeaController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Big Idea',
                    alignLabelWithHint: true,
                    hintText: 'One sentence the audience must walk away with.',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _durationController,
                  decoration: const InputDecoration(
                    labelText: 'Target Duration (minutes)',
                    prefixIcon: Icon(Icons.timer_outlined),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (v) => (int.tryParse(v ?? '') == null)
                      ? 'Number required'
                      : null,
                ),
                const SizedBox(height: 20),
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
                      child: Text(isEdit ? 'Save' : 'Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
