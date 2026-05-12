import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../core/constants/api_config.dart';
import '../models/class_profile.dart';
import '../models/doctrinal_positions.dart';
import '../models/lesson.dart';
import '../models/section.dart' as model;
import '../models/teacher_profile.dart';
import '../models/voice_corpus_item.dart';
import 'ai_context_builder.dart';
import 'claude_api_service.dart';

enum SupportDocType {
  slides('Slides', 'slides for projecting in class'),
  handout('Handout', 'a one-page student handout'),
  fillInHandout(
      'Fill-in Handout', 'a follow-along handout with key words blanked out'),
  outline('Speaker Outline', 'a speaker outline for the teacher'),
  discussionGuide('Discussion Guide', 'a small-group discussion guide');

  final String label;
  final String prompt;
  const SupportDocType(this.label, this.prompt);
}

class AiSupportDocResult {
  final bool success;
  final Uint8List? pdfBytes;
  final Map<String, dynamic>? data;
  final String? error;
  AiSupportDocResult(
      {required this.success, this.pdfBytes, this.data, this.error});
}

class AiSupportDocService {
  /// Generate a support doc. When [renderPdfDirectly] is true (default), the
  /// result includes baked PDF bytes. When false, only the parsed structured
  /// data is returned — callers (e.g. the fill-in-handout preview screen) can
  /// modify it and pass it back through [renderFromData] to get the PDF.
  static Future<AiSupportDocResult> generate({
    required SupportDocType type,
    required Lesson lesson,
    required List<model.Section> sections,
    String? seriesTitle,
    TeacherProfile? teacher,
    ClassProfile? classProfile,
    DoctrinalPositions? doctrine,
    List<VoiceCorpusItem> voiceCorpus = const [],
    bool renderPdfDirectly = true,
  }) async {
    final systemBlocks = AiContextBuilder.build(
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: voiceCorpus,
    );

    final userMessage = _composePrompt(
      type: type,
      lesson: lesson,
      sections: sections,
      seriesTitle: seriesTitle,
    );

    final response = await ClaudeApiService.call(
      systemBlocks: systemBlocks,
      userMessage: userMessage,
      maxTokens: 4096,
      model: ApiConfig.claudeOpusModel,
    );

    if (!response.success) {
      return AiSupportDocResult(success: false, error: response.error);
    }

    try {
      final json = _extractJson(response.text ?? '');
      final parsed = jsonDecode(json) as Map<String, dynamic>;
      if (!renderPdfDirectly) {
        return AiSupportDocResult(success: true, data: parsed);
      }
      final bytes = await _renderPdf(
        type: type,
        lesson: lesson,
        seriesTitle: seriesTitle,
        teacherName: teacher?.displayName ?? '',
        data: parsed,
      );
      return AiSupportDocResult(success: true, pdfBytes: bytes, data: parsed);
    } catch (e) {
      return AiSupportDocResult(
        success: false,
        error: 'Failed to render $type: $e\nRaw: ${response.text}',
      );
    }
  }

  /// Re-render a support doc from already-parsed (possibly user-edited) data.
  /// Used by the fill-in-handout preview screen after the user adjusts which
  /// words are blanks.
  static Future<Uint8List> renderFromData({
    required SupportDocType type,
    required Lesson lesson,
    String? seriesTitle,
    TeacherProfile? teacher,
    required Map<String, dynamic> data,
  }) {
    return _renderPdf(
      type: type,
      lesson: lesson,
      seriesTitle: seriesTitle,
      teacherName: teacher?.displayName ?? '',
      data: data,
    );
  }

  // ---- prompts ----

  static String _composePrompt({
    required SupportDocType type,
    required Lesson lesson,
    required List<model.Section> sections,
    String? seriesTitle,
  }) {
    final sectionDigest = sections
        .map((s) =>
            '### ${s.order + 1}. ${s.title.isEmpty ? "(untitled)" : s.title}\n${s.content}')
        .join('\n\n');
    final lessonHeader = '''
LESSON
- Series: ${seriesTitle ?? '(unspecified)'}
- Title: ${lesson.title}
- Scripture: ${lesson.scriptureReference.isEmpty ? '(unspecified)' : lesson.scriptureReference}
- Big idea: ${lesson.bigIdea.isEmpty ? '(unspecified)' : lesson.bigIdea}
- Target duration: ${lesson.targetDurationMinutes} min

SECTIONS
${sectionDigest.isEmpty ? '(no sections drafted)' : sectionDigest}

${lesson.finalizedSermonText.trim().isEmpty ? '' : 'FINALIZED SERMON TEXT:\n${lesson.finalizedSermonText}'}
''';

    switch (type) {
      case SupportDocType.slides:
        return '''
Generate ${type.prompt} for the lesson below.

$lessonHeader

OUTPUT
Respond with ONLY a JSON object — no prose before or after — in this shape:

{
  "slides": [
    {"title": "string (≤8 words)", "bullets": ["short bullet (≤9 words)", "..."], "speakerNotes": "1-2 sentence speaker note"},
    ...
  ]
}

Rules:
- 12-18 slides total: title slide, big idea, scripture, one slide per section's main beat, summary, application, prayer/closing.
- Max 5 bullets per slide; bullets are 5-9 words; titles are 3-8 words.
- Speaker notes are private cues (the teacher reads, students don't see).
- No markdown inside fields, plain text only.
''';

      case SupportDocType.handout:
        return '''
Generate ${type.prompt} for the lesson below — designed to be printed and given to students.

$lessonHeader

OUTPUT
Respond with ONLY a JSON object — no prose before or after — in this shape:

{
  "title": "string",
  "subtitle": "scripture reference",
  "bigIdea": "one-sentence big idea",
  "sections": [
    {"heading": "string", "body": "1-3 short paragraphs of plain text"},
    ...
  ],
  "memoryVerse": "verse text + reference",
  "discussionQuestions": ["...", "..."]
}

Rules:
- 3-5 sections covering: passage overview, key insight, application, response/challenge.
- Body text is plain readable prose, not bullet points. Aim for ~50-100 words per section.
- 3-5 discussion questions.
- Tone: warm, scripture-saturated, written FOR the student.
''';

      case SupportDocType.fillInHandout:
        return '''
Generate a follow-along handout for the lesson below — designed so STUDENTS write key words in the blanks while the teacher preaches the sermon. The handout reinforces memory and keeps young minds engaged.

$lessonHeader

OUTPUT
Respond with ONLY a JSON object — no prose before or after — in this shape:

{
  "title": "string",
  "subtitle": "scripture reference",
  "bigIdea": "one-sentence big idea, with the most important 1-2 KEY WORDS wrapped in double angle brackets like <<this>>",
  "sections": [
    {
      "heading": "string",
      "body": "paragraph(s) of prose. The KEY words students should fill in are wrapped in <<double angle brackets>>. Aim for 2-4 blanks per section, on truly important nouns/verbs/concepts — NOT filler words."
    },
    ...
  ],
  "memoryVerse": "verse text + reference, with 1-3 most important words wrapped in <<brackets>>",
  "applicationChallenge": "one sentence — what to DO this week"
}

Rules:
- 3-5 sections covering: passage overview, key insight, application, response/challenge.
- Body text is plain readable prose (NOT bullet points). Aim for ~60-120 words per section so students have something to read while listening.
- Wrap the answer-word(s) in <<>> exactly. The PDF will render those as underscored blanks for students to fill in.
- Blank out the words that LAND the point — nouns, verbs, concepts a 6th-12th grader should walk away knowing — not articles like "the" or "and".
- 8-15 total blanks across the whole handout. Not too sparse, not so dense it overwhelms.
- Tone: warm, scripture-saturated, written FOR the student.
''';

      case SupportDocType.outline:
        return '''
Generate ${type.prompt} for the teacher to glance at while preaching.

$lessonHeader

OUTPUT
Respond with ONLY a JSON object — no prose before or after — in this shape:

{
  "title": "string",
  "scripture": "string",
  "bigIdea": "string",
  "outline": [
    {"heading": "string", "subpoints": ["short cue", "short cue"], "speakerCue": "private reminder for the teacher"},
    ...
  ],
  "closingChallenge": "1-2 sentences"
}

Rules:
- 5-8 outline points covering the full sermon arc.
- Subpoints are short (≤10 words) — preacher reads them at-a-glance.
- speakerCue is private (illustration reminders, transitions, pacing notes).
''';

      case SupportDocType.discussionGuide:
        return '''
Generate ${type.prompt} for small-group leaders to use after the lesson.

$lessonHeader

OUTPUT
Respond with ONLY a JSON object — no prose before or after — in this shape:

{
  "title": "string",
  "scripture": "string",
  "openingPrompt": "an icebreaker or warm-up question",
  "passageQuestions": ["question 1", "question 2", ...],
  "applicationQuestions": ["question 1", "question 2", ...],
  "challengeForTheWeek": "string"
}

Rules:
- 4-6 passage questions (observe, interpret).
- 4-6 application questions (apply, respond).
- Questions are open-ended, not yes/no.
- Tone: respect 6th-12th graders as theological thinkers.
''';
    }
  }

  // ---- PDF rendering ----

  static Future<Uint8List> _renderPdf({
    required SupportDocType type,
    required Lesson lesson,
    required String? seriesTitle,
    required String teacherName,
    required Map<String, dynamic> data,
  }) async {
    final doc = pw.Document(
      title: '${type.label} — ${lesson.title}',
      author: teacherName.isEmpty ? 'Teach to Reach' : teacherName,
    );

    switch (type) {
      case SupportDocType.slides:
        _renderSlides(doc, lesson, seriesTitle, data);
        break;
      case SupportDocType.handout:
        _renderHandout(doc, lesson, data);
        break;
      case SupportDocType.fillInHandout:
        _renderFillInHandout(doc, lesson, data);
        break;
      case SupportDocType.outline:
        _renderOutline(doc, lesson, data);
        break;
      case SupportDocType.discussionGuide:
        _renderDiscussionGuide(doc, lesson, data);
        break;
    }
    return doc.save();
  }

  // 16:9 landscape pages with dark background, gold accents.
  static void _renderSlides(
    pw.Document doc,
    Lesson lesson,
    String? seriesTitle,
    Map<String, dynamic> data,
  ) {
    final slides = (data['slides'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    // Title slide.
    doc.addPage(_slidePage(
      title: lesson.title,
      bullets: [
        if (lesson.scriptureReference.isNotEmpty) lesson.scriptureReference,
        if (seriesTitle != null && seriesTitle.isNotEmpty) seriesTitle,
      ],
      speakerNotes: lesson.bigIdea,
      isTitle: true,
    ));

    for (final s in slides) {
      doc.addPage(_slidePage(
        title: (s['title'] as String?) ?? '',
        bullets: (s['bullets'] as List<dynamic>? ?? const [])
            .map((b) => b.toString())
            .toList(),
        speakerNotes: (s['speakerNotes'] as String?) ?? '',
      ));
    }
  }

  static pw.Page _slidePage({
    required String title,
    required List<String> bullets,
    String speakerNotes = '',
    bool isTitle = false,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.standard.landscape,
      build: (ctx) => pw.Container(
        color: PdfColor.fromInt(0xFF0D0D0D),
        padding: const pw.EdgeInsets.all(48),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 80,
              height: 4,
              color: PdfColor.fromInt(0xFFD4AF37),
            ),
            pw.SizedBox(height: 24),
            pw.Text(
              title,
              style: pw.TextStyle(
                color: PdfColor.fromInt(0xFFD4AF37),
                fontSize: isTitle ? 56 : 40,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 28),
            for (final b in bullets)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 14),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      margin: const pw.EdgeInsets.only(top: 12, right: 14),
                      width: 8,
                      height: 8,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFFD4AF37),
                        shape: pw.BoxShape.circle,
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Text(
                        b,
                        style: pw.TextStyle(
                          color: PdfColor.fromInt(0xFFF5F5F5),
                          fontSize: isTitle ? 24 : 28,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            pw.Spacer(),
            if (speakerNotes.isNotEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(
                      color: PdfColor.fromInt(0xFFD4AF37),
                      width: 0.5,
                    ),
                  ),
                ),
                child: pw.Text(
                  'NOTES: $speakerNotes',
                  style: pw.TextStyle(
                    color: PdfColor.fromInt(0xFFB0B0B0),
                    fontSize: 12,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static void _renderHandout(
    pw.Document doc,
    Lesson lesson,
    Map<String, dynamic> data,
  ) {
    final sections = (data['sections'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final questions = (data['discussionQuestions'] as List<dynamic>? ?? const [])
        .map((q) => q.toString())
        .toList();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) => [
        pw.Text((data['title'] as String?) ?? lesson.title,
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
        if ((data['subtitle'] as String?)?.isNotEmpty == true)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(data['subtitle'] as String,
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColor.fromInt(0xFFB8960C),
                )),
          ),
        pw.SizedBox(height: 16),
        if ((data['bigIdea'] as String?)?.isNotEmpty == true)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFAF8F0),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Text('Big idea: ${data['bigIdea']}',
                style: pw.TextStyle(
                    fontSize: 14, fontStyle: pw.FontStyle.italic)),
          ),
        pw.SizedBox(height: 18),
        for (final s in sections) ...[
          pw.Text((s['heading'] as String?) ?? '',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text((s['body'] as String?) ?? '',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 4)),
          pw.SizedBox(height: 14),
        ],
        if ((data['memoryVerse'] as String?)?.isNotEmpty == true) ...[
          pw.Divider(),
          pw.Text('Memory verse',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(data['memoryVerse'] as String,
              style: pw.TextStyle(
                  fontSize: 12, fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 12),
        ],
        if (questions.isNotEmpty) ...[
          pw.Text('Discussion questions',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          for (var i = 0; i < questions.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text('${i + 1}. ${questions[i]}',
                  style: const pw.TextStyle(fontSize: 11)),
            ),
        ],
      ],
    ));
  }

  static void _renderFillInHandout(
    pw.Document doc,
    Lesson lesson,
    Map<String, dynamic> data,
  ) {
    final sections = (data['sections'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) => [
        pw.Text((data['title'] as String?) ?? lesson.title,
            style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
        if ((data['subtitle'] as String?)?.isNotEmpty == true)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Text(data['subtitle'] as String,
                style: pw.TextStyle(
                  fontSize: 14,
                  color: PdfColor.fromInt(0xFFB8960C),
                )),
          ),
        pw.SizedBox(height: 8),
        pw.Text(
          'Listen and fill in the blanks as we go.',
          style: pw.TextStyle(
            fontSize: 11,
            fontStyle: pw.FontStyle.italic,
            color: PdfColor.fromInt(0xFF555555),
          ),
        ),
        pw.SizedBox(height: 14),
        if ((data['bigIdea'] as String?)?.isNotEmpty == true)
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFAF8F0),
              borderRadius:
                  const pw.BorderRadius.all(pw.Radius.circular(8)),
              border: pw.Border(
                left: pw.BorderSide(
                  color: PdfColor.fromInt(0xFFD4AF37),
                  width: 3,
                ),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding:
                      const pw.EdgeInsets.only(right: 8, top: 1),
                  child: pw.Text(
                    'BIG IDEA:',
                    style: pw.TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      color: PdfColor.fromInt(0xFF555555),
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.Expanded(
                  child: _fillInRichText(
                    data['bigIdea'] as String? ?? '',
                    bodyStyle: pw.TextStyle(
                      fontSize: 13,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        pw.SizedBox(height: 16),
        for (final s in sections) ...[
          pw.Text((s['heading'] as String?) ?? '',
              style: pw.TextStyle(
                  fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          _fillInRichText(
            (s['body'] as String?) ?? '',
            bodyStyle: const pw.TextStyle(fontSize: 11, lineSpacing: 5),
          ),
          pw.SizedBox(height: 16),
        ],
        if ((data['memoryVerse'] as String?)?.isNotEmpty == true) ...[
          pw.Divider(),
          pw.Text('Memory verse',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _fillInRichText(
            data['memoryVerse'] as String,
            bodyStyle: pw.TextStyle(
              fontSize: 12,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
          pw.SizedBox(height: 12),
        ],
        if ((data['applicationChallenge'] as String?)?.isNotEmpty == true) ...[
          pw.Divider(),
          pw.Text('This week, I will…',
              style: pw.TextStyle(
                  fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          _fillInRichText(
            data['applicationChallenge'] as String,
            bodyStyle: const pw.TextStyle(fontSize: 12, lineSpacing: 4),
          ),
        ],
      ],
    ));
  }

  /// Renders body text where words wrapped in <<like_this>> become underscored
  /// blanks. The underscore length scales to roughly fit the answer word so
  /// the layout previews about right when students write it in.
  static pw.Widget _fillInRichText(
    String body, {
    required pw.TextStyle bodyStyle,
  }) {
    final pattern = RegExp(r'<<([^>]+?)>>');
    final spans = <pw.InlineSpan>[];
    var lastEnd = 0;
    for (final match in pattern.allMatches(body)) {
      if (match.start > lastEnd) {
        spans.add(pw.TextSpan(
          text: body.substring(lastEnd, match.start),
          style: bodyStyle,
        ));
      }
      final answer = match.group(1) ?? '';
      // Approximate a blank that's slightly wider than the answer.
      final fill = '_' * (answer.length + 2).clamp(6, 26);
      spans.add(pw.TextSpan(
        text: fill,
        style: bodyStyle.copyWith(
          color: PdfColor.fromInt(0xFF222222),
          letterSpacing: 0.5,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < body.length) {
      spans.add(pw.TextSpan(
        text: body.substring(lastEnd),
        style: bodyStyle,
      ));
    }
    return pw.RichText(text: pw.TextSpan(children: spans, style: bodyStyle));
  }

  static void _renderOutline(
    pw.Document doc,
    Lesson lesson,
    Map<String, dynamic> data,
  ) {
    final outline = (data['outline'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) => [
        pw.Text((data['title'] as String?) ?? lesson.title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        if ((data['scripture'] as String?)?.isNotEmpty == true)
          pw.Text(data['scripture'] as String,
              style: pw.TextStyle(
                  fontSize: 13, color: PdfColor.fromInt(0xFFB8960C))),
        pw.SizedBox(height: 8),
        if ((data['bigIdea'] as String?)?.isNotEmpty == true)
          pw.Text('Big idea: ${data['bigIdea']}',
              style: pw.TextStyle(
                  fontSize: 13, fontStyle: pw.FontStyle.italic)),
        pw.SizedBox(height: 18),
        for (var i = 0; i < outline.length; i++) ...[
          pw.Text('${i + 1}. ${outline[i]['heading'] ?? ''}',
              style:
                  pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          for (final sub in (outline[i]['subpoints'] as List<dynamic>? ??
              const []))
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16, bottom: 2),
              child: pw.Text('• $sub', style: const pw.TextStyle(fontSize: 12)),
            ),
          if ((outline[i]['speakerCue'] as String?)?.isNotEmpty == true)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 16, top: 4, bottom: 8),
              child: pw.Text(
                'Cue: ${outline[i]['speakerCue']}',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromInt(0xFF888888),
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
          pw.SizedBox(height: 8),
        ],
        if ((data['closingChallenge'] as String?)?.isNotEmpty == true) ...[
          pw.Divider(),
          pw.Text('Closing challenge',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(data['closingChallenge'] as String,
              style: const pw.TextStyle(fontSize: 12)),
        ],
      ],
    ));
  }

  static void _renderDiscussionGuide(
    pw.Document doc,
    Lesson lesson,
    Map<String, dynamic> data,
  ) {
    final passageQs = (data['passageQuestions'] as List<dynamic>? ?? const [])
        .map((q) => q.toString())
        .toList();
    final applyQs = (data['applicationQuestions'] as List<dynamic>? ?? const [])
        .map((q) => q.toString())
        .toList();

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.letter,
      margin: const pw.EdgeInsets.all(48),
      build: (ctx) => [
        pw.Text((data['title'] as String?) ?? lesson.title,
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        if ((data['scripture'] as String?)?.isNotEmpty == true)
          pw.Text(data['scripture'] as String,
              style: pw.TextStyle(
                  fontSize: 13, color: PdfColor.fromInt(0xFFB8960C))),
        pw.SizedBox(height: 14),
        if ((data['openingPrompt'] as String?)?.isNotEmpty == true) ...[
          pw.Text('Opening',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(data['openingPrompt'] as String,
              style: const pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 14),
        ],
        if (passageQs.isNotEmpty) ...[
          pw.Text('In the passage',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          for (var i = 0; i < passageQs.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text('${i + 1}. ${passageQs[i]}',
                  style: const pw.TextStyle(fontSize: 12)),
            ),
          pw.SizedBox(height: 12),
        ],
        if (applyQs.isNotEmpty) ...[
          pw.Text('In our lives',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          for (var i = 0; i < applyQs.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.Text('${i + 1}. ${applyQs[i]}',
                  style: const pw.TextStyle(fontSize: 12)),
            ),
          pw.SizedBox(height: 12),
        ],
        if ((data['challengeForTheWeek'] as String?)?.isNotEmpty == true) ...[
          pw.Divider(),
          pw.Text('Challenge for the week',
              style: pw.TextStyle(
                  fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(data['challengeForTheWeek'] as String,
              style: const pw.TextStyle(fontSize: 12)),
        ],
      ],
    ));
  }

  static String _extractJson(String text) {
    final trimmed = text.trim();
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) return trimmed;
    final start = trimmed.indexOf('{');
    final end = trimmed.lastIndexOf('}');
    if (start >= 0 && end > start) {
      return trimmed.substring(start, end + 1);
    }
    return trimmed;
  }

}
