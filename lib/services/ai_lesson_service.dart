import 'dart:convert';

import '../core/constants/api_config.dart';
import '../models/class_profile.dart';
import '../models/doctrinal_positions.dart';
import '../models/lesson.dart';
import '../models/section.dart' as model;
import '../models/teacher_profile.dart';
import '../models/voice_corpus_item.dart';
import 'ai_context_builder.dart';
import 'claude_api_service.dart';

class AiLessonResult {
  final bool success;
  final String? text;
  final String? error;
  final int cacheReadTokens;
  final int cacheCreationTokens;
  final int inputTokens;
  final int outputTokens;

  AiLessonResult({
    required this.success,
    this.text,
    this.error,
    this.cacheReadTokens = 0,
    this.cacheCreationTokens = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  factory AiLessonResult.fromClaude(ClaudeResponse r) => AiLessonResult(
        success: r.success,
        text: r.text,
        error: r.error,
        cacheReadTokens: r.cacheReadTokens,
        cacheCreationTokens: r.cacheCreationTokens,
        inputTokens: r.inputTokens,
        outputTokens: r.outputTokens,
      );
}

class DeepDiveResult {
  final bool success;
  final String? eventHorizon;
  final String? authorshipHorizon;
  final String? error;

  DeepDiveResult({
    required this.success,
    this.eventHorizon,
    this.authorshipHorizon,
    this.error,
  });
}

class AiLessonService {
  /// Generate body content for a single section in a lesson.
  static Future<AiLessonResult> generateSection({
    required Lesson lesson,
    required model.Section section,
    required List<model.Section> otherSections,
    String? seriesTitle,
    String? seriesDescription,
    TeacherProfile? teacher,
    ClassProfile? classProfile,
    DoctrinalPositions? doctrine,
    List<VoiceCorpusItem> voiceCorpus = const [],
  }) async {
    final systemBlocks = AiContextBuilder.build(
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: voiceCorpus,
    );

    final userMessage = _composeSectionPrompt(
      lesson: lesson,
      section: section,
      otherSections: otherSections,
      seriesTitle: seriesTitle,
      seriesDescription: seriesDescription,
    );

    final response = await ClaudeApiService.call(
      systemBlocks: systemBlocks,
      userMessage: userMessage,
      maxTokens: 2400,
      model: ApiConfig.claudeModel,
    );
    return AiLessonResult.fromClaude(response);
  }

  /// Generate a full Study Brief for a lesson (Opus — deep call).
  static Future<AiLessonResult> generateStudyBrief({
    required Lesson lesson,
    String? seriesTitle,
    String? seriesDescription,
    TeacherProfile? teacher,
    ClassProfile? classProfile,
    DoctrinalPositions? doctrine,
    List<VoiceCorpusItem> voiceCorpus = const [],
  }) async {
    final systemBlocks = AiContextBuilder.build(
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: voiceCorpus,
    );

    final userMessage = '''
Generate a comprehensive STUDY BRIEF for this lesson. The brief is for the teacher's prep — depth and substance over polish.

LESSON CONTEXT
- Series: ${seriesTitle ?? '(unspecified)'}${seriesDescription != null && seriesDescription.isNotEmpty ? " — $seriesDescription" : ''}
- Lesson title: ${lesson.title}
- Scripture: ${lesson.scriptureReference.isEmpty ? '(unspecified)' : lesson.scriptureReference}
- Big idea: ${lesson.bigIdea.isEmpty ? '(unspecified)' : lesson.bigIdea}

REQUIRED SECTIONS (use markdown headings):
1. **Passage Overview** — what's happening, who's involved, where in the broader scriptural narrative.
2. **Original-Language Word Study** — key Hebrew/Greek terms with transliteration, base meaning, theological significance.
3. **Cross-References & Thematic Threads** — at least 5 passages that illuminate or are illuminated by this one. Brief note for each.
4. **Theological Themes** — what doctrines and emphases this passage teaches and supports.
5. **Pitfalls to Avoid** — common misreadings, weak applications, or interpretive errors.
6. **Application Angles for the Class** — practical ways to land this for 6th–12th graders given the class context.

Output as markdown. No preamble.
''';

    final response = await ClaudeApiService.call(
      systemBlocks: systemBlocks,
      userMessage: userMessage,
      maxTokens: 4096,
      model: ApiConfig.claudeOpusModel,
    );
    return AiLessonResult.fromClaude(response);
  }

  /// Generate a two-horizon Deep Dive (Opus — deep call). Returns parsed JSON
  /// with `eventHorizon` and `authorshipHorizon` markdown fields.
  static Future<DeepDiveResult> generateDeepDive({
    required Lesson lesson,
    String? seriesTitle,
    TeacherProfile? teacher,
    ClassProfile? classProfile,
    DoctrinalPositions? doctrine,
    List<VoiceCorpusItem> voiceCorpus = const [],
  }) async {
    final systemBlocks = AiContextBuilder.build(
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: voiceCorpus,
    );

    final userMessage = '''
Generate a TWO-HORIZON DEEP DIVE for this lesson.

LESSON
- Title: ${lesson.title}
- Scripture: ${lesson.scriptureReference.isEmpty ? '(unspecified)' : lesson.scriptureReference}
- Big idea: ${lesson.bigIdea.isEmpty ? '(unspecified)' : lesson.bigIdea}
- Series: ${seriesTitle ?? '(unspecified)'}

Respond with ONLY a JSON object — no prose before or after — in this exact shape:

{
  "eventHorizon": "<markdown describing what was happening at the time of the events the passage describes — political climate, surrounding cultures, daily life, religious landscape, geography. Be specific about era and location.>",
  "authorshipHorizon": "<markdown describing what was happening when the text was written — who the author was, who the original audience was, what pressures or questions they faced, why the Spirit moved this to be recorded then.>"
}

If the event and authorship are roughly contemporaneous (e.g. Paul's letters), still produce both fields with their distinct framings.

Inside each field, use full markdown — headings (### are fine), paragraphs, bold for key terms. Be substantive.
''';

    final response = await ClaudeApiService.call(
      systemBlocks: systemBlocks,
      userMessage: userMessage,
      maxTokens: 4096,
      model: ApiConfig.claudeOpusModel,
    );
    if (!response.success) {
      return DeepDiveResult(success: false, error: response.error);
    }
    try {
      final jsonText = _extractJson(response.text ?? '');
      final parsed = jsonDecode(jsonText) as Map<String, dynamic>;
      return DeepDiveResult(
        success: true,
        eventHorizon: parsed['eventHorizon'] as String? ?? '',
        authorshipHorizon: parsed['authorshipHorizon'] as String? ?? '',
      );
    } catch (e) {
      return DeepDiveResult(
        success: false,
        error: 'Failed to parse Deep Dive JSON: $e\nRaw: ${response.text}',
      );
    }
  }

  /// Apply a natural-language revision instruction to existing text.
  static Future<AiLessonResult> reviseText({
    required String originalText,
    required String userInstruction,
    TeacherProfile? teacher,
    ClassProfile? classProfile,
    DoctrinalPositions? doctrine,
    List<VoiceCorpusItem> voiceCorpus = const [],
  }) async {
    final systemBlocks = AiContextBuilder.build(
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: voiceCorpus,
    );

    final userMessage = '''
Revise the text below according to the user's instruction. Output ONLY the revised text — no preamble, no commentary, no explanation. Preserve formatting and the teacher's voice.

USER INSTRUCTION:
$userInstruction

ORIGINAL TEXT:
$originalText
''';

    final response = await ClaudeApiService.call(
      systemBlocks: systemBlocks,
      userMessage: userMessage,
      maxTokens: 4096,
      model: ApiConfig.claudeModel,
    );
    return AiLessonResult.fromClaude(response);
  }

  // ---- helpers ----

  static String _composeSectionPrompt({
    required Lesson lesson,
    required model.Section section,
    required List<model.Section> otherSections,
    String? seriesTitle,
    String? seriesDescription,
  }) {
    final buffer = StringBuffer()
      ..writeln('Draft the body content for one section of a lesson.')
      ..writeln()
      ..writeln('LESSON CONTEXT')
      ..writeln('- Series: ${seriesTitle ?? '(unspecified)'}${seriesDescription != null && seriesDescription.isNotEmpty ? " — $seriesDescription" : ''}')
      ..writeln('- Lesson title: ${lesson.title}')
      ..writeln('- Scripture: ${lesson.scriptureReference.isEmpty ? '(unspecified)' : lesson.scriptureReference}')
      ..writeln('- Big idea: ${lesson.bigIdea.isEmpty ? '(unspecified)' : lesson.bigIdea}')
      ..writeln('- Target duration: ${lesson.targetDurationMinutes} minutes total')
      ..writeln();

    if (otherSections.isNotEmpty) {
      buffer.writeln('OTHER SECTIONS IN THIS LESSON (for context, do not rewrite):');
      for (var i = 0; i < otherSections.length; i++) {
        final s = otherSections[i];
        if (s.id == section.id) continue;
        final preview = s.content.trim().split('\n').take(2).join(' ');
        buffer.writeln('  ${i + 1}. ${s.title.isEmpty ? "(untitled)" : s.title}'
            '${preview.isEmpty ? "" : " — $preview"}');
      }
      buffer.writeln();
    }

    buffer
      ..writeln('SECTION TO DRAFT')
      ..writeln('- Title: ${section.title.isEmpty ? "(untitled — propose one in the body)" : section.title}')
      ..writeln('- Position: ${section.order + 1}')
      ..writeln();

    if (section.content.trim().isNotEmpty) {
      buffer
        ..writeln('EXISTING CONTENT (revise / expand, don\'t merely rephrase):')
        ..writeln(section.content)
        ..writeln();
    }

    buffer
      ..writeln('OUTPUT')
      ..writeln('Write the section content as clean markdown. No preamble, no "Here is the section…" framing. Apply scholarship standards (Hebrew/Greek where it illuminates, cross-references, two-horizon context where relevant). Match the teacher\'s voice. Land the section appropriately for the class context. Around 200–500 words depending on the section\'s purpose.');

    return buffer.toString();
  }

  /// If the model wrapped its JSON in markdown fences or extra prose, pull
  /// the first {...} object out.
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
