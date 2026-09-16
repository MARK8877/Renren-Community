import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/home_screen.dart';
import 'package:creatorhub_app/src/screens/profile_screen.dart';
import 'package:creatorhub_app/src/widgets/chat_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ProfileAuthApi extends AuthApi {
  String nickname = '用户';
  String bio = '分享创作过程，也在这里认识同频的人。';

  @override
  Future<AuthResult> login(String id, String password) async =>
      const AuthResult('profile-test-token', '用户');

  @override
  Future<UserProfile> getProfile(String token) async => UserProfile(
    id: 1,
    nickname: nickname,
    bio: bio,
    avatarUrl: '',
    role: 'user',
  );

  @override
  Future<UserProfile> updateProfile(
    String token, {
    required String nickname,
    required String bio,
  }) async {
    this.nickname = nickname;
    this.bio = bio;
    return getProfile(token);
  }
}

void main() {
  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    SharedPreferences.setMockInitialValues({});
    final session = AuthSession(_ProfileAuthApi());
    await session.login('test@example.com', 'Test123456!');
    await tester.pumpWidget(MaterialApp(home: ProfileScreen(session: session)));
    await tester.pump();
  }

  testWidgets('底部我的入口直接切换至个人主页', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(session: AuthSession(AuthApi()))),
    );

    await tester.tap(find.byKey(const Key('nav-我的')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile-main-screen')), findsOneWidget);
    expect(find.text('像素号：PX20260908'), findsOneWidget);
    expect(find.text('关注'), findsOneWidget);
    expect(find.text('粉丝'), findsOneWidget);
    expect(find.text('获赞'), findsOneWidget);
    expect(find.byKey(const Key('share-profile')), findsNothing);
    final editPosition = tester.getTopLeft(
      find.byKey(const Key('edit-profile')),
    );
    final bioPosition = tester.getTopLeft(find.byKey(const Key('profile-bio')));
    expect(editPosition.dy, lessThan(bioPosition.dy));
  });

  testWidgets('个人主页头像使用本地头像资源组件', (tester) async {
    await pumpProfile(tester);

    final avatar = tester.widget<ChatAvatar>(
      find.byKey(const Key('profile-avatar')),
    );
    expect(avatar.isGroup, isFalse);
    expect(avatar.name, '用户');
    expect(avatar.radius, 32);
  });

  testWidgets('个人资料可编辑并立即刷新', (tester) async {
    await pumpProfile(tester);

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

    expect(find.text('像素创作者'), findsOneWidget);
    expect(find.text('专注产品设计和社区共创'), findsOneWidget);
    expect(find.text('个人资料已更新'), findsOneWidget);
  });

  testWidgets('作品动态和收藏内容可切换', (tester) async {
    await pumpProfile(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-tab-动态')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('profile-tab-动态')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-dynamic-list')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-tab-收藏')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-saved-grid')), findsOneWidget);

    await tester.tap(find.byKey(const Key('profile-tab-作品')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-works-grid')), findsOneWidget);
  });

  testWidgets('点击个人作品可进入对应视频交互页', (tester) async {
    await pumpProfile(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-tab-作品')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('profile-work-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('vertical-video-feed')), findsOneWidget);
    expect(find.byKey(const Key('close-video-feed')), findsOneWidget);
    expect(find.text('@Kevin AI'), findsOneWidget);
    expect(find.byKey(const Key('video-like-ai-workflow')), findsOneWidget);
    expect(find.byKey(const Key('video-comment-ai-workflow')), findsOneWidget);
  });

  testWidgets('创作者中心和设置页可正常进入', (tester) async {
    await pumpProfile(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('creator-center')),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('creator-center')));
    await tester.pumpAndSettle();
    expect(find.text('今日播放 3,286，新增粉丝 46'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-settings')),
      -400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const Key('profile-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-settings-screen')), findsOneWidget);
    expect(find.text('账号与安全'), findsOneWidget);
    expect(find.byKey(const Key('logout-button')), findsOneWidget);
  });

  testWidgets('创作者工具四个子页面使用工作台布局', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.byKey(const Key('creator-center')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('creator-dashboard-page')), findsOneWidget);
    expect(find.text('今日创作状态'), findsOneWidget);
    expect(find.text('发布新作品'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('revenue-center')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('revenue-dashboard-page')), findsOneWidget);
    expect(find.text('本月预估收益'), findsOneWidget);
    expect(find.text('最近收益'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('wallet')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('wallet-dashboard-page')), findsOneWidget);
    expect(find.text('可用余额'), findsOneWidget);
    expect(find.text('最近交易'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('profile-communities')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communities-dashboard-page')), findsOneWidget);
    expect(find.text('我的社区'), findsOneWidget);
    expect(find.text('进入社区'), findsWidgets);
  });

  testWidgets('内容标签位于创作者工具底部并使用紧凑入口', (tester) async {
    await pumpProfile(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('profile-content-tabs')),
      600,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byKey(const Key('profile-tools-grid')), findsOneWidget);
    expect(find.byKey(const Key('profile-content-tabs')), findsOneWidget);
    final toolsBottom = tester.getBottomRight(
      find.byKey(const Key('profile-tools-grid')),
    );
    final tabsTop = tester.getTopLeft(
      find.byKey(const Key('profile-content-tabs')),
    );
    expect(tabsTop.dy, greaterThanOrEqualTo(toolsBottom.dy));
  });

  testWidgets('关注粉丝获赞位于顶部个人信息卡片内', (tester) async {
    await pumpProfile(tester);

    final header = tester.getRect(find.byKey(const Key('profile-header')));
    final stats = tester.getRect(find.byKey(const Key('profile-header-stats')));
    expect(stats.top, greaterThan(header.top));
    expect(stats.bottom, lessThanOrEqualTo(header.bottom));
    expect(find.byKey(const Key('profile-stats-card')), findsNothing);
  });

  testWidgets('顶部个人信息卡片使用紧凑间距', (tester) async {
    await pumpProfile(tester);

    final header = tester.getRect(find.byKey(const Key('profile-header')));
    final bio = tester.getRect(find.byKey(const Key('profile-bio')));
    final stats = tester.getRect(find.byKey(const Key('profile-header-stats')));

    expect(stats.top - bio.bottom, 6);
    expect(header.bottom - stats.bottom, 0);
  });

  testWidgets('关注粉丝获赞统计行上移十像素', (tester) async {
    await pumpProfile(tester);

    final stats = tester.getRect(find.byKey(const Key('profile-header-stats')));
    final firstStat = tester.getRect(find.byKey(const Key('profile-stat-关注')));

    expect(firstStat.top - stats.top, 3);
  });

  testWidgets('个人简介与头像资料列对齐且横线贴近头像', (tester) async {
    await pumpProfile(tester);

    final avatar = tester.getRect(find.byKey(const Key('profile-avatar')));
    final stats = tester.getRect(find.byKey(const Key('profile-header-stats')));

    expect(
      find.ancestor(
        of: find.byKey(const Key('profile-bio')),
        matching: find.byKey(const Key('profile-identity-info')),
      ),
      findsOneWidget,
    );
    expect(stats.top - avatar.bottom, lessThanOrEqualTo(10));
  });

  testWidgets('关注粉丝获赞进入对应的专属子页面', (tester) async {
    await pumpProfile(tester);

    await tester.tap(find.byKey(const Key('profile-stat-关注')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-following-page')), findsOneWidget);
    expect(find.text('24 位创作者'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-stat-粉丝')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-followers-page')), findsOneWidget);
    expect(find.text('1,286 位粉丝'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile-stat-获赞')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('profile-likes-page')), findsOneWidget);
    expect(find.text('8.6万 获赞'), findsOneWidget);
  });
}
