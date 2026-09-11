import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_api.dart';

class VideoApiException implements Exception {
  const VideoApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class PlatformVideoData {
  const PlatformVideoData({
    required this.id,
    required this.platform,
    required this.externalId,
    required this.title,
    required this.playUrl,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    this.publishedAt,
  });

  final int id, likeCount, commentCount, shareCount;
  final String platform, externalId, title, playUrl;
  final DateTime? publishedAt;

  factory PlatformVideoData.fromJson(Map<String, dynamic> json) =>
      PlatformVideoData(
        id: (json['id'] as num?)?.toInt() ?? 0,
        platform: json['platform'] as String? ?? '',
        externalId: json['externalId'] as String? ?? '',
        title: json['title'] as String? ?? '',
        playUrl: json['playUrl'] as String? ?? '',
        likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
        commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
        shareCount: (json['shareCount'] as num?)?.toInt() ?? 0,
        publishedAt: json['publishedAt'] == null
            ? null
            : DateTime.tryParse(json['publishedAt'] as String)?.toLocal(),
      );
}

class VideoApi {
  VideoApi({http.Client? client, AuthApi? authApi})
    : _client = client ?? http.Client(),
      _baseUrl = (authApi ?? AuthApi()).baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<List<PlatformVideoData>> list(
    String token, {
    String? platform,
    int page = 1,
    int pageSize = 20,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'pageSize': '$pageSize',
      if (platform != null && platform.isNotEmpty) 'platform': platform,
    };
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/api/v1/videos').replace(queryParameters: query),
        headers: {'Authorization': 'Bearer $token'},
      );
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw VideoApiException(decoded['message'] as String? ?? '读取视频失败');
      }
      final items = decoded['data'] as List<dynamic>? ?? const <dynamic>[];
      return items
          .map(
            (item) => PlatformVideoData.fromJson(item as Map<String, dynamic>),
          )
          .toList();
    } on VideoApiException {
      rethrow;
    } catch (error) {
      throw VideoApiException('无法连接视频服务: $error');
    }
  }
}
