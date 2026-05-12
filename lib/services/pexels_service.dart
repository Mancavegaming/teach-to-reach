import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/constants/api_config.dart';

/// Thin wrapper over Pexels' free photo search API. Used by the slides
/// image picker to fetch stock photos based on AI-suggested keywords.
class PexelsService {
  static const String _baseUrl = 'https://api.pexels.com/v1';

  /// Searches Pexels for [query] and returns up to [perPage] candidate
  /// PexelsPhoto entries (URL + thumbnail). Photos are landscape-oriented
  /// by default, which suits 16:9 slides.
  static Future<List<PexelsPhoto>> search(
    String query, {
    int perPage = 8,
    String orientation = 'landscape',
  }) async {
    if (!ApiConfig.isPexelsConfigured) {
      throw const PexelsException('Pexels API key not configured.');
    }
    if (query.trim().isEmpty) return const [];

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'query': query,
      'per_page': perPage.toString(),
      'orientation': orientation,
    });
    final res = await http.get(
      uri,
      headers: {'Authorization': ApiConfig.pexelsApiKey},
    );
    if (res.statusCode != 200) {
      throw PexelsException('Pexels ${res.statusCode}: ${res.body}');
    }
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final photos = (body['photos'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    return photos.map(PexelsPhoto.fromJson).toList();
  }

  /// Downloads the full-quality bytes for a given Pexels photo URL.
  static Future<Uint8List> downloadBytes(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw PexelsException('Image fetch ${res.statusCode}');
    }
    return res.bodyBytes;
  }
}

class PexelsPhoto {
  final int id;
  final String photographer;
  final String fullUrl;
  final String thumbnailUrl;
  final String altText;

  const PexelsPhoto({
    required this.id,
    required this.photographer,
    required this.fullUrl,
    required this.thumbnailUrl,
    required this.altText,
  });

  factory PexelsPhoto.fromJson(Map<String, dynamic> j) {
    final src = (j['src'] as Map<String, dynamic>?) ?? const {};
    return PexelsPhoto(
      id: j['id'] as int? ?? 0,
      photographer: j['photographer'] as String? ?? '',
      fullUrl: (src['large2x'] as String?) ??
          (src['large'] as String?) ??
          (src['original'] as String?) ??
          '',
      thumbnailUrl: (src['medium'] as String?) ??
          (src['small'] as String?) ??
          (src['tiny'] as String?) ??
          '',
      altText: j['alt'] as String? ?? '',
    );
  }
}

class PexelsException implements Exception {
  final String message;
  const PexelsException(this.message);
  @override
  String toString() {
    if (kDebugMode) return 'PexelsException: $message';
    return message;
  }
}
