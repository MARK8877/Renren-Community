import 'dart:convert';

import 'package:http/http.dart' as http;

import '../auth/auth_api.dart';

class FriendApiException implements Exception {
  const FriendApiException(this.message);
  final String message;
}

class FriendUserData {
  const FriendUserData({
    required this.id,
    required this.nickname,
    required this.relationship,
    this.avatarUrl = '',
    this.identifier = '',
    this.conversationId = '',
  });

  final int id;
  final String nickname;
  final String avatarUrl;
  final String identifier;
  final String relationship;
  final String conversationId;

  factory FriendUserData.fromJson(Map<String, dynamic> json) => FriendUserData(
    id: (json['id'] as num).toInt(),
    nickname: json['nickname'] as String,
    avatarUrl: json['avatarUrl'] as String? ?? '',
    identifier: json['identifier'] as String? ?? '',
    relationship: json['relationship'] as String? ?? 'none',
    conversationId: json['conversationId'] as String? ?? '',
  );
}

class FriendRequestData {
  const FriendRequestData({
    required this.id,
    required this.userId,
    required this.nickname,
    required this.createdAt,
    this.avatarUrl = '',
  });

  final int id;
  final int userId;
  final String nickname;
  final String avatarUrl;
  final DateTime createdAt;

  factory FriendRequestData.fromJson(Map<String, dynamic> json) =>
      FriendRequestData(
        id: (json['id'] as num).toInt(),
        userId: (json['userId'] as num).toInt(),
        nickname: json['nickname'] as String,
        avatarUrl: json['avatarUrl'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

class FriendApi {
  FriendApi({http.Client? client, AuthApi? authApi})
    : _client = client ?? http.Client(),
      _baseUrl = (authApi ?? AuthApi()).baseUrl;

  final http.Client _client;
  final String _baseUrl;

  Future<List<FriendUserData>> friends(String token) async {
    final data = await _request('GET', '/api/v1/friends', token);
    return (data as List<dynamic>)
        .map((item) => FriendUserData.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendRequestData>> incomingRequests(String token) async {
    final data = await _request('GET', '/api/v1/friend-requests', token);
    return (data as List<dynamic>)
        .map((item) => FriendRequestData.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<FriendUserData>> search(String token, String keyword) async {
    final query = Uri.encodeQueryComponent(keyword.trim());
    final data = await _request('GET', '/api/v1/users/search?q=$query', token);
    return (data as List<dynamic>)
        .map((item) => FriendUserData.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendRequest(String token, int userId) => _request(
    'POST',
    '/api/v1/friend-requests',
    token,
    body: {'userId': userId},
  );

  Future<void> accept(String token, int requestId) =>
      _request('POST', '/api/v1/friend-requests/$requestId/accept', token);

  Future<void> reject(String token, int requestId) =>
      _request('POST', '/api/v1/friend-requests/$requestId/reject', token);

  Future<dynamic> _request(
    String method,
    String path,
    String token, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl$path');
      final headers = {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      };
      final response = method == 'GET'
          ? await _client.get(uri, headers: headers)
          : await _client.post(
              uri,
              headers: headers,
              body: body == null ? null : jsonEncode(body),
            );
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw FriendApiException(decoded['message'] as String? ?? '请求失败');
      }
      return decoded['data'];
    } on FriendApiException {
      rethrow;
    } catch (_) {
      throw const FriendApiException('无法连接好友服务器');
    }
  }
}
