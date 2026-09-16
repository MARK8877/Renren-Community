import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_api.dart';

class HomeFeedPost {
  const HomeFeedPost({
    required this.id,
    required this.source,
    required this.author,
    required this.role,
    required this.content,
    required this.tags,
    required this.url,
    required this.scrapedAt,
  });

  final int id;
  final String source, author, role, content, url;
  final List<String> tags;
  final DateTime scrapedAt;

  factory HomeFeedPost.fromJson(Map<String, dynamic> json) => HomeFeedPost(
    id: (json['id'] as num?)?.toInt() ?? 0,
    source: json['source'] as String? ?? '',
    author: json['author'] as String? ?? '',
    role: json['role'] as String? ?? '',
    content: json['content'] as String? ?? '',
    tags: (json['tags'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .toList(growable: false),
    url: json['url'] as String? ?? '',
    scrapedAt:
        DateTime.tryParse(json['scrapedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

class HomeFeedApi {
  HomeFeedApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? AuthApi().baseUrl;

  final http.Client _client;
  final String baseUrl;

  Future<List<HomeFeedPost>> list(
    String token, {
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl/api/v1/home/posts',
      ).replace(queryParameters: {'page': '$page', 'pageSize': '$pageSize'});
      final response = await _client.get(
        uri,
        headers: {'Authorization': 'Bearer $token'},
      );
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(json['message'] as String? ?? '读取首页动态失败');
      }
      return (json['data'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HomeFeedPost.fromJson)
          .toList(growable: false);
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('无法连接服务器，请检查网络后重试');
    }
  }
}
