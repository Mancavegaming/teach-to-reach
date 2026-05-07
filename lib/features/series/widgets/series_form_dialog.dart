import 'package:flutter/material.dart';

import '../../../models/series.dart';

class SeriesFormDialog extends StatefulWidget {
  final Series? initial;
  final String ownerId;

  const SeriesFormDialog({
    super.key,
    this.initial,
    required this.ownerId,
  });

  @override
  State<SeriesFormDialog> createState() => _SeriesFormDialogState();
}

class _SeriesFormDialogState extends State<SeriesFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _ageGroupController;
  late final TextEditingController _audienceController;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initial?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.initial?.description ?? '');
    _ageGroupController = TextEditingController(
        text: widget.initial?.ageGroup ?? '6th-12th grade');
    _audienceController =
        TextEditingController(text: widget.initial?.targetAudience ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _ageGroupController.dispose();
    _audienceController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final result = (widget.initial ??
            Series(ownerId: widget.ownerId, title: _titleController.text.trim()))
        .copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      ageGroup: _ageGroupController.text.trim(),
      targetAudience: _audienceController.text.trim(),
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
                        isEdit ? 'Edit Series' : 'New Series',
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
                    labelText: 'Series Title',
                    prefixIcon: Icon(Icons.title),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title required'
                      : null,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    alignLabelWithHint: true,
                    hintText: 'What does this series cover? Why now?',
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _ageGroupController,
                  decoration: const InputDecoration(
                    labelText: 'Age Group',
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _audienceController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Target Audience (optional)',
                    alignLabelWithHint: true,
                    hintText: 'Boys at risk, mixed group, new believers...',
                  ),
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
