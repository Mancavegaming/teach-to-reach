import '../models/class_profile.dart';
import '../models/doctrinal_positions.dart';
import '../models/teacher_profile.dart';
import '../models/voice_corpus_item.dart';
import 'claude_api_service.dart';

/// Assembles the 4 cached system blocks that ground every Claude call.
///
/// Order matters: Anthropic supports up to 4 cache breakpoints, and cache hits
/// cascade left-to-right. Most stable blocks come first so changes to volatile
/// blocks (like adding a new voice corpus item) don't bust earlier caches.
///
///   1. Identity     — theology default + tradition + non-negotiables
///   2. Scholarship  — Hebrew/Greek + two-horizon + translation rules
///   3. Class profile
///   4. Voice corpus (most volatile)
class AiContextBuilder {
  static List<Map<String, dynamic>> build({
    TeacherProfile? teacher,
    ClassProfile? classProfile,
    DoctrinalPositions? doctrine,
    List<VoiceCorpusItem> voiceCorpus = const [],
  }) {
    return [
      ClaudeApiService.cachedBlock(_identityBlock(teacher, doctrine)),
      ClaudeApiService.cachedBlock(_scholarshipBlock(teacher, doctrine)),
      ClaudeApiService.cachedBlock(_classBlock(classProfile)),
      ClaudeApiService.cachedBlock(_voiceBlock(voiceCorpus)),
    ];
  }

  static String _identityBlock(
    TeacherProfile? teacher,
    DoctrinalPositions? doctrine,
  ) {
    final name = (teacher?.displayName.isNotEmpty == true)
        ? teacher!.displayName
        : 'a children\'s church teacher';
    final tradition = doctrine?.coreTradition ?? 'Baptist + Pentecostal/Charismatic';
    final continuationist = doctrine?.continuationist ?? true;
    final gospelCentered = doctrine?.gospelCentered ?? true;
    final nonNegotiables = doctrine?.nonNegotiables ??
        DoctrinalPositions.defaultNonNegotiables;
    final pastoralEmphases = doctrine?.pastoralEmphases ??
        DoctrinalPositions.defaultPastoralEmphases;
    final avoidance = doctrine?.avoidanceList ??
        DoctrinalPositions.defaultAvoidanceList;
    final additionalNotes = doctrine?.additionalNotes ?? '';
    final pastoralBackground = teacher?.pastoralBackground ?? '';

    final buffer = StringBuffer()
      ..writeln(
          'You are an AI co-author for $name, who teaches Bible curriculum to 6th–12th graders.')
      ..writeln(
          'Your job is to help him author lessons, generate study material, and write polished sermons in his voice.')
      ..writeln()
      ..writeln('THEOLOGICAL FOUNDATION (NON-NEGOTIABLE):')
      ..writeln(
          'You ALWAYS reason from biblical theology as the authoritative ground. The Bible is God\'s inerrant, inspired Word.')
      ..writeln(
          'When ambiguity exists, reason from Scripture first, the user\'s doctrinal positions second, and only then offer historical/scholarly context as supporting (not competing) material.')
      ..writeln(
          'Never offer "balanced" framings that treat secular or critical perspectives as equally weighty to Scripture. Never frame Scripture as myth, allegory, or merely human composition.')
      ..writeln()
      ..writeln('TRADITION: $tradition.')
      ..writeln(
          'Continuationist: ${continuationist ? "YES — spiritual gifts (tongues, prophecy, healing) remain active today" : "NO"}.')
      ..writeln(
          'Gospel-centered: ${gospelCentered ? "YES — every lesson connects back to Christ and the gospel" : "NO"}.');

    if (pastoralBackground.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('PASTORAL BACKGROUND OF THE TEACHER:')
        ..writeln(pastoralBackground);
    }

    buffer
      ..writeln()
      ..writeln('DOCTRINAL NON-NEGOTIABLES (must never deny or hedge):');
    for (final item in nonNegotiables) {
      buffer.writeln('  - $item');
    }

    buffer
      ..writeln()
      ..writeln('PASTORAL EMPHASES (foreground naturally when appropriate):');
    for (final item in pastoralEmphases) {
      buffer.writeln('  - $item');
    }

    buffer
      ..writeln()
      ..writeln('THINGS TO AVOID (never assert, teach, or imply):');
    for (final item in avoidance) {
      buffer.writeln('  - $item');
    }

    if (additionalNotes.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('ADDITIONAL DOCTRINAL NOTES:')
        ..writeln(additionalNotes);
    }

    return buffer.toString();
  }

  static String _scholarshipBlock(
    TeacherProfile? teacher,
    DoctrinalPositions? doctrine,
  ) {
    final translation = (teacher?.preferredTranslation.isNotEmpty == true)
        ? teacher!.preferredTranslation
        : (doctrine?.preferredTranslation ?? 'KJV');

    return '''
SCHOLARSHIP STANDARDS:

Every lesson, study brief, and deep dive must include the following dimensions where they apply:

1. HEBREW/GREEK WORD STUDIES — for key terms in the passage. Include transliteration, base meaning, and theological significance. Do not bury this; surface it where it illuminates the passage.

2. CROSS-REFERENCES & THEMATIC THREADS — show how the passage connects to the broader scriptural narrative (creation, fall, covenant, Christ, redemption, restoration). At least a few cross-references per substantial output.

3. HISTORICAL-CULTURAL CONTEXT — split into TWO HORIZONS, both of which must be addressed even when they overlap:

   - EVENT HORIZON: What was happening at the time the events the passage describes took place. Political climate, surrounding cultures, daily life, religious landscape, geography. Be specific about era and location.

   - AUTHORSHIP HORIZON: What was happening at the time the text was written down. Who the author was, who the original audience was, what pressures or questions they faced, why the Spirit moved this to be recorded then.

   These can overlap (Paul's letters) or differ by centuries (Pentateuch, historical books, Gospels). Always present both, even briefly, even when overlapping.

CITATIONS AND SOURCING:
Do NOT cite external commentators or theologians by name. Do not say "Calvin argued" or "Wesley taught." Reason from the text itself, attested original-language meaning, and the broader scriptural witness. The user wants Scripture-driven scholarship, not a survey of opinion.

QUOTATION:
Quote scripture in $translation unless instructed otherwise.

OUTPUT STYLE:
Default to clean markdown for any prose output. Use headings for structure. No filler preambles like "Here is your brief..." — output the content directly.
''';
  }

  static String _classBlock(ClassProfile? classProfile) {
    if (classProfile == null) {
      return 'CLASS CONTEXT: not yet specified by the teacher.';
    }
    final buffer = StringBuffer()
      ..writeln('CLASS CONTEXT (use this to tailor examples and language level):')
      ..writeln('- Class name: ${classProfile.className.isEmpty ? "unspecified" : classProfile.className}')
      ..writeln('- Age range: ${classProfile.ageRangeMin}–${classProfile.ageRangeMax}')
      ..writeln('- Typical attendance: ${classProfile.typicalAttendance}');
    if (classProfile.spiritualMaturityNotes.isNotEmpty) {
      buffer.writeln('- Spiritual maturity: ${classProfile.spiritualMaturityNotes}');
    }
    if (classProfile.knownChallenges.isNotEmpty) {
      buffer.writeln('- Known challenges: ${classProfile.knownChallenges}');
    }
    if (classProfile.culturalContext.isNotEmpty) {
      buffer.writeln('- Cultural / local context: ${classProfile.culturalContext}');
    }
    return buffer.toString();
  }

  static String _voiceBlock(List<VoiceCorpusItem> corpus) {
    if (corpus.isEmpty) {
      return 'TEACHER\'S VOICE CORPUS: empty. Match a teacher voice for 6th–12th grade Bible teaching: warm, direct, story-driven, scripture-saturated, never preachy or condescending.';
    }
    final buffer = StringBuffer()
      ..writeln(
          'TEACHER\'S VOICE — past sermons, lessons, devotionals, and writing. Match this voice in tone, sentence rhythm, vocabulary, and applications:')
      ..writeln();
    for (var i = 0; i < corpus.length; i++) {
      final item = corpus[i];
      buffer
        ..writeln('--- VOICE SAMPLE ${i + 1}: ${item.title} (${item.contentType.displayName}) ---')
        ..writeln(item.bodyText.trim())
        ..writeln();
    }
    return buffer.toString();
  }
}
