import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_api.dart';

class AuthSession extends ChangeNotifier {
  AuthSession(this.api);

  static const accessTokenKey = 'access_token';
  static const nicknameKey = 'nickname';

  final AuthApi api;
  String? _token, _nickname;
  bool ready = false;
  bool get signedIn => _token != null;
  String? get accessToken => _token;
  String get nickname => _nickname ?? '用户';

  Future<void> restore() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedToken = preferences.getString(accessTokenKey)?.trim();
      final savedNickname = preferences.getString(nicknameKey)?.trim();

      if (savedToken == null || savedToken.isEmpty) {
        _token = null;
        _nickname = null;
      } else {
        _token = savedToken;
        _nickname = savedNickname == null || savedNickname.isEmpty
            ? null
            : savedNickname;
      }
    } catch (_) {
      _token = null;
      _nickname = null;
    } finally {
      ready = true;
      notifyListeners();
    }
  }

  Future<void> login(String id, String password) async =>
      _save(await api.login(id, password));
  Future<void> register(String id, String password, String nickname) async =>
      _save(await api.register(id, password, nickname));
  Future<UserProfile> getProfile() async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const AuthException('请先登录');
    }
    return api.getProfile(token);
  }

  Future<UserProfile> updateProfile({
    required String nickname,
    required String bio,
  }) async {
    final token = _token;
    if (token == null || token.isEmpty) {
      throw const AuthException('请先登录');
    }
    final profile = await api.updateProfile(
      token,
      nickname: nickname,
      bio: bio,
    );
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(nicknameKey, profile.nickname);
    _nickname = profile.nickname;
    notifyListeners();
    return profile;
  }

  Future<void> _save(AuthResult r) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(accessTokenKey, r.token);
    await preferences.setString(nicknameKey, r.nickname);
    _token = r.token;
    _nickname = r.nickname;
    notifyListeners();
  }

  Future<void> logout() async {
    _token = null;
    _nickname = null;
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(accessTokenKey);
    await preferences.remove(nicknameKey);
    notifyListeners();
  }
}
