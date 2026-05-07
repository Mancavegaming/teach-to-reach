// API Configuration
//
// API keys are injected at build time via --dart-define:
//   flutter run --dart-define=CLAUDE_API_KEY=sk-ant-...

class ApiConfig {
  static const String claudeBaseUrl = 'https://api.anthropic.com/v1';

  // Default model for lesson and section generation. High quality + good speed.
  static const String claudeModel = 'claude-sonnet-4-6';

  // For deep theological work (full lesson drafts, study briefs).
  static const String claudeOpusModel = 'claude-opus-4-7';

  // For fast, cheap calls (e.g. short rephrases).
  static const String claudeHaikuModel = 'claude-haiku-4-5-20251001';

  static const String claudeApiVersion = '2023-06-01';

  static const String _claudeApiKey = String.fromEnvironment('CLAUDE_API_KEY');

  static String get claudeApiKey => _claudeApiKey;

  static bool get isClaudeConfigured => _claudeApiKey.isNotEmpty;
}
