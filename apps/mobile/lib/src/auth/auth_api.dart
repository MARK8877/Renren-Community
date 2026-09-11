import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

class AuthResult {
  const AuthResult(this.token, this.nickname);
  final String token, nickname;
}

class AuthApi {
  AuthApi({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? _defaultBaseUrl();

  static String _defaultBaseUrl() {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    if (kIsWeb) return 'http://localhost:18080';
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:18080'
        : 'http://localhost:18080';
  }

  final http.Client _client;
  final String baseUrl;
  Future<AuthResult> login(String id, String password) =>
      _submit('/api/v1/auth/login', {'identifier': id, 'password': password});
  Future<AuthResult> register(String id, String password, String nickname) =>
      _submit('/api/v1/auth/register', {
        'identifier': id,
        'password': password,
        'nickname': nickname,
      });
  Future<AuthResult> _submit(String path, Map<String, String> body) async {
    try {
      final res = await _client.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw AuthException(json['message'] as String? ?? '请求失败');
      }
      final data = json['data'] as Map<String, dynamic>;
      final user = data['user'] as Map<String, dynamic>;
      return AuthResult(
        data['accessToken'] as String,
        user['nickname'] as String,
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('无法连接服务器，请检查网络后重试');
    }
  }
}
