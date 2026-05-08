import '../core/constants/api_config.dart';
import '../features/annotation/services/annotation_renderer.dart';
import '../models/class_profile.dart';
import '../models/doctrinal_positions.dart';
import '../models/lesson.dart';
import '../models/sermon_annotation.dart';
import '../models/teacher_profile.dart';
import '../models/voice_corpus_item.dart';
import 'ai_context_builder.dart';
import 'ai_lesson_service.dart';
import 'claude_api_service.dart';

class AiPenRevisionService {
  /// Submit a sermon's handwritten annotations to Claude vision and get back
  /// a revised sermon text that incorporates the user's pen edits.
  ///
  /// Pipeline:
  /// 1. Render the sermon text + ink strokes into a single PNG.
  /// 2. Send PNG + original text + cached identity/scholarship/voice/class
  ///    blocks to Opus 4.7's vision endpoint.
  /// 3. Return the revised sermon text (markdown).
  ///
  /// On the calling side, present the result in a diff view (Original vs
  /// Revised) and let the user accept, reject, or re-prompt.
  static Future<AiLessonResult> reviseFromAnnotation({
    required Lesson lesson,
    required SermonAnnotation annotation,
    TeacherProfile? teacher,
    ClassProfile? classProfile,
    DoctrinalPositions? doctrine,
    List<VoiceCorpusItem> voiceCorpus = const [],
  }) async {
    if (lesson.finalizedSermonText.trim().isEmpty) {
      return AiLessonResult(
        success: false,
        error:
            'Lesson has no finalized sermon text — finalize it before submitting pen edits.',
      );
    }
    if (annotation.strokes.isEmpty) {
      return AiLessonResult(
        success: false,
        error: 'No pen strokes to send. Draw your edits first, save, then submit.',
      );
    }

    final imageBytes = await AnnotationRenderer.render(
      text: lesson.finalizedSermonText,
      strokes: annotation.strokes,
      canvasWidth: annotation.canvasWidth,
      canvasHeight: annotation.canvasHeight,
    );

    final systemBlocks = AiContextBuilder.build(
      teacher: teacher,
      classProfile: classProfile,
      doctrine: doctrine,
      voiceCorpus: voiceCorpus,
    );

    final userMessage = '''
The image shows the finalized sermon text with my handwritten edits drawn on top in colored ink.

INTERPRET MY EDITS PRECISELY. Common ink conventions to watch for:
- Strikethrough lines through words → delete those words
- Margin notes / arrows pointing into the text → insert that content where indicated
- Underlines or circles → emphasize, expand, or rewrite that passage
- Vertical bars in the margin → that paragraph needs attention; revise per any nearby note
- Question marks → user is uncertain about that line; re-examine and improve
- Caret (^) symbols → insert text at that point
- "Move" arrows or numbers → reorder

WHAT TO PRODUCE:
Apply my edits to the sermon. Preserve everything I did NOT mark up, exactly. Keep my voice (you have my voice corpus in your system context). Maintain scholarship standards (Hebrew/Greek where it illuminates, cross-references, two-horizon historical context where relevant).

OUTPUT
Return ONLY the revised sermon text as clean markdown. No preamble. No commentary about what you changed. No "here's the revised text" framing — just the sermon.

If any of my handwriting is genuinely illegible, make your best inference from context and proceed; do not stop to ask. If a marking is ambiguous (e.g. a line that could be strikethrough or underline), prefer the interpretation that produces the more meaningful edit.

ORIGINAL SERMON TEXT (this is what's printed in the image, character-for-character):
${lesson.finalizedSermonText}
''';

    final response = await ClaudeApiService.callWithImage(
      systemBlocks: systemBlocks,
      userMessage: userMessage,
      imageBytes: imageBytes,
      mediaType: 'image/png',
      maxTokens: 6144,
      model: ApiConfig.claudeOpusModel,
    );
    return AiLessonResult.fromClaude(response);
  }
}
