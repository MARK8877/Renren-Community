import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ShortDramaApiException implements Exception {
  const ShortDramaApiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ShortDramaEpisodeData {
  const ShortDramaEpisodeData({
    required this.episode,
    required this.title,
    required this.m3u8Url,
    this.duration = 0,
  });

  final int episode, duration;
  final String title, m3u8Url;

  factory ShortDramaEpisodeData.fromJson(Map<String, dynamic> json) =>
      ShortDramaEpisodeData(
        episode: (json['episode'] as num?)?.toInt() ?? 0,
        title: json['title'] as String? ?? '',
        m3u8Url:
            (json['m3u8url'] ?? json['m3u8Url'] ?? json['url']) as String? ??
            '',
        duration: (json['duration'] as num?)?.toInt() ?? 0,
      );
}

class ShortDramaData {
  const ShortDramaData({
    required this.id,
    required this.name,
    required this.totalEpisodes,
    required this.episodes,
  });

  final int id, totalEpisodes;
  final String name;
  final List<ShortDramaEpisodeData> episodes;

  factory ShortDramaData.fromJson(Map<String, dynamic> json) => ShortDramaData(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    totalEpisodes: (json['totalEpisodes'] as num?)?.toInt() ?? 0,
    episodes: ((json['episodes'] as List<dynamic>?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(ShortDramaEpisodeData.fromJson)
        .toList(),
  );
}

class ShortDramaPlayback {
  const ShortDramaPlayback({required this.url, required this.duration});
  final String url;
  final int duration;
}

class ShortDramaApi {
  ShortDramaApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? _defaultBaseUrl();

  final http.Client _client;
  final String _baseUrl;

  static String _defaultBaseUrl() {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return 'http://localhost:18080';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:18080'
        : 'http://localhost:18080';
  }

  Future<List<ShortDramaData>> list(
    String token, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$_baseUrl/api/v1/short-dramas',
        ).replace(queryParameters: {'page': '$page', 'pageSize': '$pageSize'}),
        headers: {'Authorization': 'Bearer $token'},
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _checkResponse(response.statusCode, json);
      return ((json['data'] as List<dynamic>?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ShortDramaData.fromJson)
          .toList();
    } on ShortDramaApiException {
      rethrow;
    } catch (error) {
      throw ShortDramaApiException('无法连接短剧服务: $error');
    }
  }

  Future<ShortDramaPlayback> playUrl(
    String token,
    int dramaId,
    int episode,
  ) async {
    try {
      final response = await _client.get(
        Uri.parse(
          '$_baseUrl/api/v1/short-dramas/$dramaId/episodes/$episode/play-url',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      _checkResponse(response.statusCode, json);
      final data = json['data'] as Map<String, dynamic>? ?? const {};
      return ShortDramaPlayback(
        url: data['url'] as String? ?? '',
        duration: (data['duration'] as num?)?.toInt() ?? 0,
      );
    } on ShortDramaApiException {
      rethrow;
    } catch (error) {
      throw ShortDramaApiException('无法连接短剧服务: $error');
    }
  }

  void _checkResponse(int status, Map<String, dynamic> json) {
    if (status < 200 || status >= 300) {
      throw ShortDramaApiException(json['message'] as String? ?? '读取短剧失败');
    }
  }
}
