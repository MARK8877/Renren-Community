import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/home_screen.dart';
import 'package:creatorhub_app/src/widgets/chat_avatar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpHome(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(session: AuthSession(AuthApi()))),
    );
  }

  testWidgets('首页使用创作者紫渐变背景层', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-background-gradient')), findsOneWidget);
  });

  testWidgets('首页展示突出搜索入口', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-search-bar')), findsOneWidget);
    expect(find.text('搜索创作者、社区和话题'), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.search), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.mic), findsOneWidget);
  });

  testWidgets('顶部频道不与通知重叠并使用统一线性图标', (tester) async {
    await pumpHome(tester);
    await tester.pumpAndSettle();

    final hotTab = tester.getRect(find.byKey(const Key('top-tab-热门')));
    final notification = tester.getRect(find.byKey(const Key('header-通知')));
    expect(hotTab.right, lessThanOrEqualTo(notification.left));
    expect(find.byIcon(CupertinoIcons.bell), findsOneWidget);
  });

  testWidgets('发布按钮进入动态发布页并将内容插入首页', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('nav-publish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-publish-screen')), findsOneWidget);

    const content = '这是新发布的社区动态';
    await tester.enterText(find.byKey(const Key('publish-content')), content);
    await tester.tap(find.byKey(const Key('publish-topic-#经验分享')));
    await tester.tap(find.byKey(const Key('publish-submit')));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text(content),
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 10,
    );
    expect(find.text(content), findsOneWidget);
    expect(find.text('#经验分享'), findsOneWidget);
  });

  testWidgets('发布动态时可创建群聊并从动态进入群聊', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('nav-publish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('publish-create-group')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publish-group-name')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('publish-content')),
      '欢迎加入设计共创讨论',
    );
    await tester.enterText(
      find.byKey(const Key('publish-group-name')),
      '设计共创群',
    );
    await tester.pump();
    final publishButton = tester.widget<FilledButton>(
      find.byKey(const Key('publish-submit')),
    );
    expect(publishButton.onPressed, isNotNull);
    await tester.tap(find.byKey(const Key('publish-submit')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const PageStorageKey<String>('home-feed-scroll')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const Key('community-设计共创群')),
      350,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 8,
    );
    await tester.pumpAndSettle();
    expect(find.text('设计共创群'), findsOneWidget);
    expect(find.text('1 位成员'), findsOneWidget);

    await tester.tap(find.byKey(const Key('community-设计共创群')));
    await tester.pumpAndSettle();
    expect(find.text('设计共创群'), findsOneWidget);
    expect(find.byKey(const Key('chat-input')), findsOneWidget);
  });

  testWidgets('主页原型展示核心区域', (tester) async {
    await pumpHome(tester);

    expect(find.text('推荐'), findsOneWidget);
    expect(find.text('AI创作'), findsOneWidget);
    expect(find.text('设计共创'), findsOneWidget);
    expect(find.text('本周热议'), findsNothing);
    expect(find.text('活跃群聊'), findsNothing);
    expect(find.text('从分镜到成片'), findsOneWidget);
    expect(find.text('18,420 人'), findsOneWidget);
    expect(find.text('推荐动态'), findsOneWidget);
    expect(find.text('用 AI 制作短视频，我最常用的 5 个步骤'), findsOneWidget);
    expect(find.text('AI 视频创作者交流群'), findsOneWidget);
    expect(find.byKey(const Key('post-image-ai-video')), findsOneWidget);
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('视频'), findsOneWidget);
    expect(find.text('消息'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);
  });

  testWidgets('首页作者头像使用本地头像资源组件', (tester) async {
    await pumpHome(tester);

    await tester.dragUntilVisible(
      find.byKey(const Key('home-author-avatar-Ada Product')),
      find.byKey(const PageStorageKey<String>('home-feed-scroll')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    final avatar = tester.widget<ChatAvatar>(
      find.byKey(const Key('home-author-avatar-Ada Product')),
    );
    expect(avatar.name, 'Ada Product');
    expect(avatar.radius, 20);
  });

  testWidgets('首页使用推荐式入口且动态保持单列', (tester) async {
    await pumpHome(tester);

    expect(find.byKey(const Key('editorial-home-header')), findsOneWidget);
    expect(find.byKey(const Key('home-search-bar')), findsOneWidget);
    expect(find.byKey(const Key('editorial-category-rail')), findsOneWidget);
    expect(find.byKey(const Key('home-quick-entry-grid')), findsOneWidget);
    expect(find.byKey(const Key('home-highlight-row')), findsOneWidget);
    expect(find.byKey(const Key('weekly-hot-entry')), findsOneWidget);
    expect(find.byKey(const Key('active-group-entry')), findsOneWidget);
    expect(
      tester.widget(find.byKey(const Key('home-single-column-feed'))),
      isA<SliverList>(),
    );
  });

  testWidgets('产品设计共创群使用本地多人拼图头像', (tester) async {
    await pumpHome(tester);

    final avatar = tester.widget<ChatAvatar>(
      find.descendant(
        of: find.byKey(const Key('active-group-entry')),
        matching: find.byKey(const Key('home-design-group-avatar')),
      ),
    );
    expect(avatar.isGroup, isTrue);
    expect(avatar.members.length, greaterThan(1));
  });

  testWidgets('AI视频卡片使用前景材质承载渐变背景', (tester) async {
    await pumpHome(tester);

    final foregroundMaterial = find.ancestor(
      of: find.byKey(const Key('weekly-hot-entry')),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Material && widget.type == MaterialType.transparency,
      ),
    );
    expect(foregroundMaterial, findsOneWidget);
  });

  testWidgets('AI视频卡片渐变保持深色并承载白色文字', (tester) async {
    await pumpHome(tester);

    final ink = tester.widget<Ink>(
      find.descendant(
        of: find.byKey(const Key('weekly-hot-entry')),
        matching: find.byType(Ink),
      ),
    );
    final gradient = (ink.decoration! as BoxDecoration).gradient!;
    expect(
      gradient.colors.every((color) => color.computeLuminance() < 0.18),
      isTrue,
    );
  });

  testWidgets('宽屏下快捷入口第二行完整显示', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(498, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: HomeScreen(session: AuthSession(AuthApi()))),
    );
    await tester.pumpAndSettle();

    final rail = tester.getRect(
      find.byKey(const Key('editorial-category-rail')),
    );
    final lastEntry = tester.getRect(find.text('更多'));
    expect(lastEntry.bottom, lessThanOrEqualTo(rail.bottom));
  });

  testWidgets('社区动态图片提前预取并完成渐显', (tester) async {
    await pumpHome(tester);

    final feed = tester.widget<CustomScrollView>(
      find.byKey(const PageStorageKey<String>('home-feed-scroll')),
    );
    expect(feed.scrollCacheExtent?.value, 1.25);

    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 300)),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('post-image-ai-video-loaded')), findsOneWidget);
    expect(
      find.byKey(const Key('post-image-ai-video-placeholder')),
      findsNothing,
    );
  });

  testWidgets('首页上拉至底部自动加载更多动态', (tester) async {
    await pumpHome(tester);

    final feedFinder = find.byKey(
      const PageStorageKey<String>('home-feed-scroll'),
    );
    final position = tester
        .widget<CustomScrollView>(feedFinder)
        .controller!
        .position;
    final initialExtent = position.maxScrollExtent;

    await tester.fling(feedFinder, const Offset(0, -3000), 3000);
    await tester.pumpAndSettle();

    expect(position.maxScrollExtent, greaterThan(initialExtent));
    expect(find.byKey(const Key('home-refresh-indicator')), findsOneWidget);
  });

  testWidgets('首页下拉刷新后恢复初始数据', (tester) async {
    await pumpHome(tester);

    final feedFinder = find.byKey(
      const PageStorageKey<String>('home-feed-scroll'),
    );
    await tester.drag(feedFinder, const Offset(0, 360));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('已刷新最新内容'), findsOneWidget);
    expect(find.byKey(const Key('home-refresh-indicator')), findsOneWidget);
  });

  testWidgets('图文动态使用朋友圈紧凑网格并支持全屏图片预览', (tester) async {
    await pumpHome(tester);

    expect(find.byKey(const Key('post-image-ai-video')), findsOneWidget);
    await tester.dragUntilVisible(
      find.byKey(const Key('post-image-community-design')),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    expect(
      find.byKey(const Key('post-image-community-design')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('post-image-community-design-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('post-image-community-design-2')),
      findsOneWidget,
    );

    final grid = tester.widget<GridView>(
      find.byKey(const Key('post-image-community-design-grid')),
    );
    final delegate =
        grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
    expect(delegate.crossAxisCount, 2);
    final imageGridSize = tester.getSize(
      find.byKey(const Key('post-image-community-design')),
    );
    expect(imageGridSize.width, closeTo(288, 0.1));
    expect(imageGridSize.height, closeTo(142, 0.1));

    await tester.ensureVisible(
      find.byKey(const Key('post-image-community-design-1')),
    );
    await tester.pumpAndSettle();

    final topAlignedImage = tester.widget<Image>(
      find.byKey(const Key('post-image-community-design-1-loaded')),
    );
    expect(topAlignedImage.fit, BoxFit.cover);
    expect(topAlignedImage.alignment, Alignment.topCenter);
    expect(topAlignedImage.width, double.infinity);
    expect(topAlignedImage.height, double.infinity);
    expect(
      find.descendant(
        of: find.byKey(const Key('post-image-community-design')),
        matching: find.byType(AnimatedSwitcher),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('post-image-community-design')),
        matching: find.byType(Hero),
      ),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('post-image-community-design-1')));
    await tester.pump();

    expect(find.byKey(const Key('community-image-preview')), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.byType(Hero), findsNothing);

    await tester.drag(
      find.byKey(const Key('community-image-preview-pages')),
      const Offset(-320, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.byKey(const Key('community-preview-image-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('community-preview-image-2')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('community-preview-image-2')));
    await tester.pumpAndSettle();
    final preview = tester.widget<InteractiveViewer>(
      find.descendant(
        of: find.byKey(const Key('community-preview-image-2')),
        matching: find.byType(InteractiveViewer),
      ),
    );
    expect(
      preview.transformationController!.value.getMaxScaleOnAxis(),
      greaterThan(1),
    );

    await tester.tap(find.byKey(const Key('close-community-image-preview')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-image-preview')), findsNothing);
  });

  testWidgets('视频动态使用朋友圈式左对齐缩略图', (tester) async {
    await pumpHome(tester);

    final mediaSize = tester.getSize(
      find.byKey(const Key('moments-video-media')),
    );
    expect(mediaSize.width, 252);
    expect(mediaSize.height, 189);
    expect(mediaSize.width / mediaSize.height, closeTo(4 / 3, 0.01));
    expect(find.text('00:36'), findsOneWidget);
  });

  testWidgets('顶部频道和分类可以切换', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('top-tab-关注')));
    await tester.pumpAndSettle();
    expect(find.text('已切换到关注内容'), findsOneWidget);
    expect(find.byKey(const Key('following-empty-state')), findsOneWidget);
    expect(find.text('还没有关注任何创作者'), findsOneWidget);
    expect(find.byKey(const Key('editorial-category-rail')), findsNothing);

    await tester.tap(find.byKey(const Key('top-tab-推荐')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('editorial-category-rail')), findsOneWidget);
    await tester.tap(find.byKey(const Key('category-AI')));
    await tester.pumpAndSettle();
    expect(find.text('正在查看AI分类'), findsOneWidget);
  });

  testWidgets('关注频道只展示已关注创作者并可返回推荐', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('follow-Kevin AI')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('top-tab-关注')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('following-empty-state')), findsNothing);
    expect(find.text('用 AI 制作短视频，我最常用的 5 个步骤'), findsOneWidget);
    expect(find.text('设计师如何建立自己的创作者社区？'), findsNothing);

    await tester.tap(find.byKey(const Key('top-tab-推荐')));
    await tester.pumpAndSettle();
    expect(find.text('推荐动态'), findsOneWidget);
    expect(find.byKey(const Key('following-empty-state')), findsNothing);
  });

  testWidgets('关注空状态可进入推荐且热门频道按互动排序', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('top-tab-关注')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('following-explore')));
    await tester.pumpAndSettle();
    expect(find.text('推荐动态'), findsOneWidget);

    await tester.tap(find.byKey(const Key('top-tab-热门')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hot-channel-hint')), findsOneWidget);
    expect(find.text('按点赞与评论互动热度排序'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('sample-post-football-night')),
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 8,
    );
    expect(find.byKey(const Key('sample-post-football-night')), findsOneWidget);
  });

  testWidgets('内容卡片支持关注、播放、加入、点赞和收藏', (tester) async {
    await pumpHome(tester);

    await tester.ensureVisible(find.byKey(const Key('follow-Kevin AI')));
    await tester.tap(find.byKey(const Key('follow-Kevin AI')));
    await tester.pump();
    expect(find.text('已关注'), findsOneWidget);

    await tester.tap(find.byKey(const Key('video-play')));
    await tester.pump();
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('community-AI 视频创作者交流群')));
    await tester.tap(find.byKey(const Key('community-AI 视频创作者交流群')));
    await tester.pumpAndSettle();
    expect(find.text('群公告：请遵守群规，友善交流，共同成长。'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('已加入'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('like-video')));
    await tester.tap(find.byKey(const Key('like-video')));
    await tester.tap(find.byKey(const Key('bookmark-video')));
    await tester.pump();
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
  });

  testWidgets('底部导航和发布按钮提供操作反馈', (tester) async {
    await pumpHome(tester);

    expect(find.byKey(const Key('ios-glass-tab-bar')), findsOneWidget);
    expect(find.byKey(const Key('ios-glass-tab-surface')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('ios-glass-tab-bar')),
        matching: find.byType(BackdropFilter),
      ),
      findsNWidgets(2),
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).extendBody,
      isTrue,
    );

    await tester.tap(find.byKey(const Key('nav-视频')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('vertical-video-feed')), findsOneWidget);
    expect(find.byKey(const Key('close-video-feed')), findsNothing);

    await tester.tap(find.byKey(const Key('nav-首页')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-search-bar')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-publish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('community-publish-screen')), findsOneWidget);
  });

  testWidgets('底部标签栏使用统一线性图标和轻量反馈', (tester) async {
    await pumpHome(tester);

    final tabBar = find.byKey(const Key('ios-glass-tab-bar'));
    expect(
      find.descendant(
        of: tabBar,
        matching: find.byIcon(Icons.video_library_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: tabBar, matching: find.byIcon(Icons.forum_outlined)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tabBar,
        matching: find.byIcon(Icons.account_circle_outlined),
      ),
      findsOneWidget,
    );
    final scales = tester.widgetList<AnimatedScale>(
      find.descendant(of: tabBar, matching: find.byType(AnimatedScale)),
    );
    expect(scales, isNotEmpty);
    expect(
      scales.every(
        (scale) => scale.duration == const Duration(milliseconds: 180),
      ),
      isTrue,
    );
  });

  testWidgets('底部消息入口进入消息中心并可返回首页', (tester) async {
    await pumpHome(tester);

    await tester.tap(find.byKey(const Key('nav-消息')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('messages-main-screen')), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byKey(const Key('unified-conversation-list')), findsOneWidget);
    expect(find.text('AI 视频创作者交流群'), findsOneWidget);
    expect(find.text('Luna Design'), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-首页')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-search-bar')), findsOneWidget);
  });
}
