import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/app.dart';
import 'package:creatorhub_app/src/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthApi extends AuthApi {
  String? loginIdentifier;
  String? loginPassword;
  String? registerIdentifier;
  String? registerPassword;
  String? registerNickname;

  @override
  Future<AuthResult> login(String id, String password) async {
    loginIdentifier = id;
    loginPassword = password;
    return const AuthResult('test-token', '测试用户');
  }

  @override
  Future<AuthResult> register(
    String id,
    String password,
    String nickname,
  ) async {
    registerIdentifier = id;
    registerPassword = password;
    registerNickname = nickname;
    return AuthResult('register-token', nickname);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('登录页默认填充测试账号和密码', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(session: AuthSession(_MockAuthApi()))),
    );

    final identifierField = tester.widget<TextFormField>(
      find.byKey(const Key('login-identifier')),
    );
    final passwordField = tester.widget<TextFormField>(
      find.byKey(const Key('login-password')),
    );

    expect(identifierField.controller?.text, 'test@example.com');
    expect(passwordField.controller?.text, 'Test123456!');
    final passwordEditable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('login-password')),
        matching: find.byType(EditableText),
      ),
    );
    expect(passwordEditable.obscureText, isTrue);
  });

  testWidgets('测试账号可通过登录页写入会话', (tester) async {
    final api = _MockAuthApi();
    final session = AuthSession(api);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(session: session)));

    await tester.enterText(
      find.widgetWithText(TextFormField, '手机号或邮箱'),
      '  test@example.com  ',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '密码'),
      'Test123456!',
    );
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(api.loginIdentifier, 'test@example.com');
    expect(api.loginPassword, 'Test123456!');
    expect(session.signedIn, isTrue);
    expect(session.nickname, '测试用户');
    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString(AuthSession.accessTokenKey), 'test-token');
    expect(preferences.getString(AuthSession.nicknameKey), '测试用户');
  });

  testWidgets('关闭按钮可退出当前登录页', (tester) async {
    final session = AuthSession(_MockAuthApi());
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(session: session),
                  ),
                ),
                child: const Text('打开登录页'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开登录页'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('close-login-page')), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-login-page')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('close-login-page')), findsNothing);
    expect(find.text('打开登录页'), findsOneWidget);
  });

  testWidgets('登录成功后自动进入主页', (tester) async {
    final api = _MockAuthApi();
    final session = AuthSession(api);
    await session.restore();

    await tester.pumpWidget(CreatorHubApp(session: session));
    expect(find.text('欢迎回到\n像素社区'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, '手机号或邮箱'),
      'test@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '密码'),
      'Test123456!',
    );
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pumpAndSettle();

    expect(find.text('欢迎回到\n像素社区'), findsNothing);
    expect(find.text('像素社区'), findsOneWidget);
    expect(find.text('刷视频，遇见同频的人'), findsOneWidget);
  });

  testWidgets('已有登录信息时启动后直接进入主页', (tester) async {
    SharedPreferences.setMockInitialValues({
      AuthSession.accessTokenKey: 'saved-token',
      AuthSession.nicknameKey: '测试用户',
    });
    final session = AuthSession(_MockAuthApi());

    await tester.pumpWidget(CreatorHubApp(session: session));
    await tester.pumpAndSettle();

    expect(find.text('欢迎回到\n像素社区'), findsNothing);
    expect(find.text('像素社区'), findsOneWidget);
  });

  test('登录状态在会话重新创建后仍能恢复', () async {
    final firstSession = AuthSession(_MockAuthApi());
    await firstSession.login('test@example.com', 'Test123456!');

    final restoredSession = AuthSession(_MockAuthApi());
    await restoredSession.restore();

    expect(restoredSession.ready, isTrue);
    expect(restoredSession.signedIn, isTrue);
    expect(restoredSession.nickname, '测试用户');
  });

  test('退出登录后清除持久化状态', () async {
    final session = AuthSession(_MockAuthApi());
    await session.login('test@example.com', 'Test123456!');
    await session.logout();

    final restoredSession = AuthSession(_MockAuthApi());
    await restoredSession.restore();
    final preferences = await SharedPreferences.getInstance();

    expect(restoredSession.signedIn, isFalse);
    expect(preferences.getString(AuthSession.accessTokenKey), isNull);
    expect(preferences.getString(AuthSession.nicknameKey), isNull);
  });

  testWidgets('注册页校验协议并提交注册信息', (tester) async {
    final api = _MockAuthApi();
    final session = AuthSession(api);
    await tester.pumpWidget(MaterialApp(home: LoginScreen(session: session)));

    await tester.tap(find.text('没有账号？立即注册'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, '昵称'), '新用户');
    await tester.enterText(
      find.widgetWithText(TextFormField, '手机号或邮箱'),
      'new@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, '密码'),
      'NewUser123!',
    );

    await tester.tap(find.widgetWithText(FilledButton, '注册'));
    await tester.pump();
    expect(find.text('请先同意用户协议和隐私政策'), findsOneWidget);
    expect(api.registerIdentifier, isNull);

    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.widgetWithText(FilledButton, '注册'));
    await tester.pumpAndSettle();

    expect(api.registerIdentifier, 'new@example.com');
    expect(api.registerPassword, 'NewUser123!');
    expect(api.registerNickname, '新用户');
    expect(session.signedIn, isTrue);
    expect(find.text('欢迎回到\n像素社区'), findsOneWidget);
  });
}
