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

    final imageTiles = await AnnotationRenderer.renderTiles(
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

    final pageNote = imageTiles.length == 1
        ? 'The image shows the finalized sermon text with my handwritten edits drawn on top in colored ink.'
        : 'The ${imageTiles.length} images, in order, are consecutive vertical pages of the same finalized sermon. Each page is labeled "Page N of ${imageTiles.length}" in its top-left corner. Read them top-to-bottom as one continuous document. My handwritten edits are drawn on top of the printed text in colored ink.';

    final userMessage = '''
$pageNote

YOU ARE WRITING AS THE PASTOR. My handwritten markings on the page are author instructions to YOU. Read every single annotation, no matter how small, including text in parentheses, arrows pointing to specific places, and notes scribbled in the margins. Nothing is decorative — every mark is a directive.

INK CONVENTIONS:
- Strikethrough lines through words → delete those words
- Caret (^), arrows, or insertion marks → insert content there
- Margin notes (anywhere off the printed text body) → write fresh sermon material at the indicated location
- Notes in parentheses like "(include Romans 8:28)" or "(talk about the struggles of the world here)" or "(add a story)" → these are AUTHOR INSTRUCTIONS, not literal text to keep. EXPAND each one into real sermon prose: write the verse exegesis, the application, the illustration, etc. Do NOT paste the parenthetical text back verbatim. Do NOT skip them.
- Underlines, circles, vertical bars → emphasize, expand, or rewrite that passage
- Question marks → I'm uncertain — re-examine and improve
- "Move" arrows or numbered marks → reorder

WHAT TO PRODUCE:
You are a pastor writing a sermon. Apply every annotation to the original text. Where I asked you to add a verse, write the verse + exposition. Where I asked you to cover a topic, write 1-3 paragraphs of sermon prose on it in my voice. Where I struck text, remove it cleanly so the prose still flows. Preserve everything I did NOT mark up exactly as printed. Match my voice (you have my voice corpus in your system context). Maintain scholarship standards (Hebrew/Greek where it illuminates, cross-references, two-horizon historical context where relevant).

If any of my handwriting is genuinely illegible, make your best inference from context and proceed. If a marking is ambiguous (e.g. could be strikethrough or underline), prefer the interpretation that produces the more meaningful edit.

OUTPUT
Return ONLY the revised sermon text as clean markdown. No preamble. No "here's the revised text" framing. No commentary about what you changed. Just the sermon, ready to preach.

ORIGINAL SERMON TEXT (this is what's printed in the image, character-for-character):
${lesson.finalizedSermonText}
''';

    final response = await ClaudeApiService.callWithImages(
      systemBlocks: systemBlocks,
      userMessage: userMessage,
      images: imageTiles,
      mediaType: 'image/png',
      maxTokens: 6144,
      model: ApiConfig.claudeOpusModel,
    );
    return AiLessonResult.fromClaude(response);
  }
}
