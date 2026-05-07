import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../services/ai_lesson_service.dart';
import '../../../services/class_profile_service.dart';
import '../../../services/doctrinal_positions_service.dart';
import '../../../services/teacher_profile_service.dart';
import '../../../services/voice_corpus_service.dart';

/// Returns the accepted revised text via Navigator.pop, or null if cancelled.
class AiReviseDialog extends StatefulWidget {
  final String originalText;
  final String label;
  const AiReviseDialog({
    super.key,
    required this.originalText,
    this.label = 'this text',
  });

  @override
  State<AiReviseDialog> createState() => _AiReviseDialogState();
}

class _AiReviseDialogState extends State<AiReviseDialog> {
  final _instructionController = TextEditingController();
  bool _busy = false;
  String? _revised;
  String? _error;

  @override
  void dispose() {
    _instructionController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final instruction = _instructionController.text.trim();
    if (instruction.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final teacher = context.read<TeacherProfileService>().profile;
    final classProfile = context.read<ClassProfileService>().profile;
    final doctrine = context.read<DoctrinalPositionsService>().positions;
    final corpus = context.read<VoiceCorpusService>().items;
    final result = await AiLessonService.reviseText(
      originalText: widget.originalText,
      userInstruction: instruction,
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: corpus,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.success) {
        _revised = result.text;
      } else {
        _error = result.error;
      }
    });
  }

  void _accept() {
    if (_revised != null) {
      Navigator.of(context).pop(_revised);
    }
  }

  void _discardRevision() {
    setState(() {
      _revised = null;
      _instructionController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _revised == null
                          ? 'Ask AI to change ${widget.label}'
                          : 'Review revision',
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
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.error, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                ),
              if (_revised == null)
                Expanded(child: _composeView())
              else
                Expanded(child: _diffView()),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_revised != null) ...[
                    TextButton.icon(
                      onPressed: _busy ? null : _discardRevision,
                      icon: const Icon(Icons.replay),
                      label: const Text('Try a different instruction'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _accept,
                      icon: const Icon(Icons.check),
                      label: const Text('Accept revision'),
                    ),
                  ] else ...[
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _busy ||
                              _instructionController.text.trim().isEmpty
                          ? null
                          : _apply,
                      icon: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(_busy ? 'Applying…' : 'Apply'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composeView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _instructionController,
          maxLines: 3,
          minLines: 2,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'How should the AI change it?',
            alignLabelWithHint: true,
            hintText:
                'e.g. shorten by half, add a story, simpler language, more KJV quotes...',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        Text('Original',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.primary,
                  letterSpacing: 1.0,
                )),
        const SizedBox(height: 6),
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: SelectableText(
                widget.originalText.isEmpty ? '(empty)' : widget.originalText,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _diffView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 720;
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _diffPanel('Original', widget.originalText, false)),
              const SizedBox(width: 14),
              Expanded(child: _diffPanel('Revised', _revised ?? '', true)),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: _diffPanel('Original', widget.originalText, false)),
            const SizedBox(height: 12),
            Expanded(child: _diffPanel('Revised', _revised ?? '', true)),
          ],
        );
      },
    );
  }

  Widget _diffPanel(String label, String text, bool highlight) {
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
