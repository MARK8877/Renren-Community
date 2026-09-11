import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/home_screen.dart';
import 'package:creatorhub_app/src/screens/profile_screen.dart';
import 'package:creatorhub_app/src/widgets/chat_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: ProfileScreen(session: AuthSession(AuthApi()))),
    );
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
}
