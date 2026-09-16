import 'dart:convert';

import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/community_publish_screen.dart';
import 'package:creatorhub_app/src/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('编辑资料调用接口并同步登录会话', (tester) async {
    final client = _ProfileClient();
    final session = AuthSession(
      AuthApi(client: client, baseUrl: 'http://test.local'),
    );
    await session.login('test@example.com', 'Test123456!');

    await tester.pumpWidget(MaterialApp(home: ProfileScreen(session: session)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('edit-profile')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('profile-nickname-input')),
      '像素创作者',
    );
    await tester.enterText(
      find.byKey(const Key('profile-bio-input')),
      '专注产品设计和社区共创',
    );
    await tester.tap(find.byKey(const Key('save-profile')));
    await tester.pumpAndSettle();

    expect(client.updatedProfile, {'nickname': '像素创作者', 'bio': '专注产品设计和社区共创'});
    expect(session.nickname, '像素创作者');
    expect(find.text('个人资料已更新'), findsOneWidget);
  });

  testWidgets('发布动态展示个人资料接口返回的发布者信息', (tester) async {
    final client = _ProfileClient();
    final session = AuthSession(
      AuthApi(client: client, baseUrl: 'http://test.local'),
    );
    await session.login('test@example.com', 'Test123456!');

    await tester.pumpWidget(
      MaterialApp(home: CommunityPublishScreen(session: session)),
    );
    await tester.pumpAndSettle();

    expect(find.text('远端创作者'), findsOneWidget);
    final avatar = tester.widget<CircleAvatar>(
      find.byKey(const Key('publish-author-avatar')),
    );
    expect(avatar.foregroundImage, isA<NetworkImage>());
    expect(
      (avatar.foregroundImage! as NetworkImage).url,
      'https://example.com/creator-avatar.png',
    );
    expect(client.loadedProfile, isTrue);
  });
}

class _ProfileClient extends http.BaseClient {
  Map<String, dynamic>? updatedProfile;
  bool loadedProfile = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'POST' && request.url.path == '/api/v1/auth/login') {
      return _response(request, 200, {
        'code': 0,
        'message': 'ok',
        'data': {
          'accessToken': 'test-token',
          'user': {'id': 1, 'nickname': '本地昵称', 'role': 'user'},
        },
      });
    }
    if (request.method == 'GET' && request.url.path == '/api/v1/auth/me') {
      loadedProfile = true;
      return _response(request, 200, _profileResponse());
    }
    if (request.method == 'PATCH' && request.url.path == '/api/v1/auth/me') {
      updatedProfile =
          jsonDecode(await request.finalize().bytesToString())
              as Map<String, dynamic>;
      return _response(request, 200, _profileResponse(updatedProfile!));
    }
    return _response(request, 404, {'code': 10404, 'message': 'not found'});
  }

  Map<String, dynamic> _profileResponse([Map<String, dynamic>? update]) => {
    'code': 0,
    'message': 'ok',
    'data': {
      'id': 1,
      'nickname': update?['nickname'] ?? '远端创作者',
      'bio': update?['bio'] ?? '来自数据库的个人简介',
      'avatarUrl': 'https://example.com/creator-avatar.png',
      'role': 'user',
    },
  };

  http.StreamedResponse _response(
    http.BaseRequest request,
    int status,
    Map<String, dynamic> body,
  ) => http.StreamedResponse(
    Stream<List<int>>.fromIterable([utf8.encode(jsonEncode(body))]),
    status,
    request: request,
    headers: const {'content-type': 'application/json'},
  );
}
