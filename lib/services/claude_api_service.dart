import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/constants/api_config.dart';

/// Centralized Claude API service with multi-block prompt caching.
///
/// Anthropic supports up to 4 cache breakpoints in the system prompt.
/// Teach to Reach uses this for: theological identity, scholarship standards,
/// teacher voice corpus, and class profile — each as its own cached block so
/// changes to one (e.g. adding a new sermon to the voice corpus) don't bust
/// the cache on the others.
class ClaudeApiService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';
  static const String _apiVersion = '2023-06-01';
  static const String _cacheBeta = 'prompt-caching-2024-07-31';

  /// Wrap a single string into a cached system block.
  static Map<String, dynamic> cachedBlock(String text) => {
        'type': 'text',
        'text': text,
        'cache_control': {'type': 'ephemeral'},
      };

  /// Wrap a single string into an uncached system block.
  static Map<String, dynamic> textBlock(String text) => {
        'type': 'text',
        'text': text,
      };

  /// Make a Claude API call with arbitrary system blocks.
  ///
  /// Each block in [systemBlocks] may have its own `cache_control`. Blocks are
  /// concatenated in order; cache hits cascade (so put your most-stable blocks
  /// first — identity, scholarship — and your most-volatile last — voice, class).
  static Future<ClaudeResponse> call({
    required List<Map<String, dynamic>> systemBlocks,
    required String userMessage,
    int maxTokens = 4096,
    String? model,
  }) async {
    if (!ApiConfig.isClaudeConfigured) {
      return ClaudeResponse(
        success: false,
        error: 'Claude API key not configured. Run with --dart-define=CLAUDE_API_KEY=...',
      );
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ApiConfig.claudeApiKey,
          'anthropic-version': _apiVersion,
          'anthropic-beta': _cacheBeta,
          // Required for direct calls from a browser (CORS). Harmless on
          // native (iPad/macOS) clients. Acceptable here because this is a
          // single-user app where the user controls the build and the key.
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: jsonEncode({
          'model': model ?? ApiConfig.claudeModel,
          'max_tokens': maxTokens,
          'system': systemBlocks,
          'messages': [
            {
              'role': 'user',
              'content': userMessage,
            }
          ],
        }),
      );

      return _parseResponse(response);
    } catch (e) {
      debugPrint('Claude API call failed: $e');
      return ClaudeResponse(success: false, error: e.toString());
    }
  }

  /// Convenience: call with a single cached system prompt string.
  static Future<ClaudeResponse> callWithSystemPrompt({
    required String systemPrompt,
    required String userMessage,
    int maxTokens = 4096,
    String? model,
  }) {
    return call(
      systemBlocks: [cachedBlock(systemPrompt)],
      userMessage: userMessage,
      maxTokens: maxTokens,
      model: model,
    );
  }

  /// Make a Claude API call with conversation history.
  static Future<ClaudeResponse> callWithHistory({
    required List<Map<String, dynamic>> systemBlocks,
    required List<Map<String, String>> messages,
    int maxTokens = 4096,
    String? model,
  }) async {
    if (!ApiConfig.isClaudeConfigured) {
      return ClaudeResponse(
        success: false,
        error: 'Claude API key not configured.',
      );
    }

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ApiConfig.claudeApiKey,
          'anthropic-version': _apiVersion,
          'anthropic-beta': _cacheBeta,
          'anthropic-dangerous-direct-browser-access': 'true',
        },
        body: jsonEncode({
          'model': model ?? ApiConfig.claudeModel,
          'max_tokens': maxTokens,
          'system': systemBlocks,
          'messages': messages,
        }),
      );

      return _parseResponse(response);
    } catch (e) {
      debugPrint('Claude API call failed: $e');
      return ClaudeResponse(success: false, error: e.toString());
    }
  }

  static ClaudeResponse _parseResponse(http.Response response) {
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['content'];

      final usage = data['usage'] as Map<String, dynamic>?;
      final cacheCreationTokens = usage?['cache_creation_input_tokens'] ?? 0;
      final cacheReadTokens = usage?['cache_read_input_tokens'] ?? 0;
      final inputTokens = usage?['input_tokens'] ?? 0;
      final outputTokens = usage?['output_tokens'] ?? 0;

      if (kDebugMode) {
        debugPrint('Claude API: input=$inputTokens output=$outputTokens '
            'cacheRead=$cacheReadTokens cacheCreate=$cacheCreationTokens');
      }

      if (content != null && content.isNotEmpty) {
        return ClaudeResponse(
          success: true,
          text: content[0]['text'] as String,
          cacheCreationTokens: cacheCreationTokens,
          cacheReadTokens: cacheReadTokens,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
        );
      }
      return ClaudeResponse(success: false, error: 'Empty response');
    }

    try {
      final errorData = jsonDecode(response.body);
      final errorMessage = errorData['error']?['message'] ?? 'HTTP ${response.statusCode}';
      debugPrint('Claude API Error: ${response.statusCode} - $errorMessage');
      return ClaudeResponse(success: false, error: errorMessage);
    } catch (_) {
      return ClaudeResponse(
        success: false,
        error: 'HTTP ${response.statusCode}: ${response.body}',
      );
    }
  }
}

class ClaudeResponse {
  final bool success;
  final String? text;
  final String? error;
  final int cacheCreationTokens;
  final int cacheReadTokens;
  final int inputTokens;
  final int outputTokens;

  ClaudeResponse({
    required this.success,
    this.text,
    this.error,
    this.cacheCreationTokens = 0,
    this.cacheReadTokens = 0,
    this.inputTokens = 0,
    this.outputTokens = 0,
  });

  bool get wasCacheHit => cacheReadTokens > 0;
}
