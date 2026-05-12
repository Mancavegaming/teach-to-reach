import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/lesson.dart';
import '../../../services/ai_support_doc_service.dart';
import '../../../services/teacher_profile_service.dart';

/// Review the AI-chosen fill-in blanks before exporting. Each word in the
/// handout body is tappable; tap a normal word to blank it, tap an already-
/// blanked word (shown highlighted with an underline) to restore it.
class FillInHandoutPreviewScreen extends StatefulWidget {
  final Lesson lesson;
  final String? seriesTitle;
  final Map<String, dynamic> data;

  const FillInHandoutPreviewScreen({
    super.key,
    required this.lesson,
    required this.data,
    this.seriesTitle,
  });

  @override
  State<FillInHandoutPreviewScreen> createState() =>
      _FillInHandoutPreviewScreenState();
}

class _FillInHandoutPreviewScreenState
    extends State<FillInHandoutPreviewScreen> {
  /// Editable copy of the parsed JSON. The user toggles `<<word>>` markers
  /// in `bigIdea`, each section's `body`, `memoryVerse`, and
  /// `applicationChallenge`.
  late Map<String, dynamic> _data;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _data = _deepCloneJson(widget.data);
  }

  int get _blankCount {
    final pattern = RegExp(r'<<[^>]+>>');
    var n = 0;
    for (final field in _stringFields()) {
      n += pattern.allMatches(field).length;
    }
    return n;
  }

  Iterable<String> _stringFields() sync* {
    yield (_data['bigIdea'] as String?) ?? '';
    yield (_data['memoryVerse'] as String?) ?? '';
    yield (_data['applicationChallenge'] as String?) ?? '';
    final sections = (_data['sections'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    for (final s in sections) {
      yield (s['body'] as String?) ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Fill-in handout: ${widget.lesson.title}',
            overflow: TextOverflow.ellipsis),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$_blankCount blanks',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 110),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LegendCard(),
                      const SizedBox(height: 16),
                      _editableTitle(),
                      const SizedBox(height: 16),
                      _editableField(
                        label: 'BIG IDEA',
                        getter: () => (_data['bigIdea'] as String?) ?? '',
                        setter: (v) => _data['bigIdea'] = v,
                      ),
                      const SizedBox(height: 20),
                      ..._buildSections(),
                      _editableField(
                        label: 'MEMORY VERSE',
                        getter: () =>
                            (_data['memoryVerse'] as String?) ?? '',
                        setter: (v) => _data['memoryVerse'] = v,
                      ),
                      const SizedBox(height: 16),
                      _editableField(
                        label: 'THIS WEEK, I WILL…',
                        getter: () =>
                            (_data['applicationChallenge'] as String?) ?? '',
                        setter: (v) =>
                            _data['applicationChallenge'] = v,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _exporting ? null : _resetEdits,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset to AI choices'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _exporting ? null : _exportPdf,
                          icon: _exporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.picture_as_pdf_outlined),
                          label: Text(_exporting
                              ? 'Building PDF…'
                              : 'Export PDF'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editableTitle() {
    final title = (_data['title'] as String?) ?? widget.lesson.title;
    final subtitle = (_data['subtitle'] as String?) ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold)),
        if (subtitle.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(subtitle,
                style: TextStyle(color: AppColors.primary, fontSize: 14)),
          ),
      ],
    );
  }

  List<Widget> _buildSections() {
    final sections = (_data['sections'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return [
      for (var i = 0; i < sections.length; i++) ...[
        Text(
          (sections[i]['heading'] as String?) ?? '',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        _BlankableBody(
          text: (sections[i]['body'] as String?) ?? '',
          onChanged: (newText) {
            setState(() => sections[i]['body'] = newText);
          },
        ),
        const SizedBox(height: 18),
      ],
    ];
  }

  Widget _editableField({
    required String label,
    required String Function() getter,
    required void Function(String) setter,
  }) {
    final value = getter();
    if (value.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.primary,
                letterSpacing: 1.4,
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        _BlankableBody(
          text: value,
          onChanged: (newText) => setState(() => setter(newText)),
        ),
      ],
    );
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    final teacher = context.read<TeacherProfileService>().profile;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = await AiSupportDocService.renderFromData(
        type: SupportDocType.fillInHandout,
        lesson: widget.lesson,
        seriesTitle: widget.seriesTitle,
        teacher: teacher,
        data: _data,
      );
      if (!mounted) return;
      setState(() => _exporting = false);
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${widget.lesson.title} - Fill-in.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      messenger.showSnackBar(
        SnackBar(content: Text('PDF export failed: $e')),
      );
    }
  }

  void _resetEdits() {
    setState(() => _data = _deepCloneJson(widget.data));
  }

  static Map<String, dynamic> _deepCloneJson(Map<String, dynamic> src) {
    final clone = <String, dynamic>{};
    src.forEach((k, v) {
      if (v is Map<String, dynamic>) {
        clone[k] = _deepCloneJson(v);
      } else if (v is List) {
        clone[k] = v
            .map((e) => e is Map<String, dynamic> ? _deepCloneJson(e) : e)
            .toList();
      } else {
        clone[k] = v;
      }
    });
    return clone;
  }
}

class _LegendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.touch_app, color: AppColors.primary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tap any word to toggle whether it becomes a blank. '
                'Highlighted = blank in the student PDF.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders body text as tappable word-chips. Words marked `<<like_this>>` in
/// the source string are shown highlighted; tapping unwraps them. Tapping a
/// plain word wraps it.
class _BlankableBody extends StatelessWidget {
  final String text;
  final ValueChanged<String> onChanged;

  const _BlankableBody({required this.text, required this.onChanged});

  static final RegExp _tokenPattern = RegExp(r'<<[^>]+>>|\S+|\s+');

  @override
  Widget build(BuildContext context) {
    final tokens = _tokenPattern.allMatches(text).map((m) => m.group(0)!).toList();

    final widgets = <Widget>[];
    for (var i = 0; i < tokens.length; i++) {
      final tok = tokens[i];
      if (tok.trim().isEmpty) {
        widgets.add(const SizedBox(width: 4));
        continue;
      }
      final isBlank = tok.startsWith('<<') && tok.endsWith('>>');
      final display = isBlank ? tok.substring(2, tok.length - 2) : tok;
      widgets.add(_WordChip(
        display: display,
        isBlank: isBlank,
        onTap: () {
          tokens[i] = isBlank ? display : '<<$display>>';
          onChanged(tokens.join());
        },
      ));
    }

    return Wrap(
      spacing: 2,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: widgets,
    );
  }
}

class _WordChip extends StatelessWidget {
  final String display;
  final bool isBlank;
  final VoidCallback onTap;

  const _WordChip({
    required this.display,
    required this.isBlank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: isBlank
              ? Colors.yellow.withValues(alpha: 0.55)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: isBlank
              ? null
              : Border.all(
                  color: Colors.transparent,
                  width: 0,
                ),
        ),
        child: Text(
          display,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            decoration: isBlank ? TextDecoration.underline : null,
            decorationStyle: TextDecorationStyle.dashed,
            decorationColor: Colors.black54,
            fontWeight: isBlank ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
