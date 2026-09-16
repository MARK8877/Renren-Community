import 'dart:convert';

import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/video_feed_screen.dart';
import 'package:creatorhub_app/src/video/video_api.dart';
import 'package:creatorhub_app/src/widgets/chat_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  Future<void> pumpVideoFeed(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: VideoFeedScreen(session: AuthSession(AuthApi()))),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
  }

  testWidgets('视频页不叠加全屏渐变蒙层（按钮渐变除外）', (tester) async {
    await pumpVideoFeed(tester);

    final gradientOverlays = find.byWidgetPredicate(
      (widget) =>
          widget is DecoratedBox &&
          widget.key == null &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).gradient != null,
    );
    expect(gradientOverlays, findsNothing);
  });

  testWidgets('视频操作层去除实心背景并保留透明悬浮样式', (tester) async {
    await pumpVideoFeed(tester);

    final description = tester.widget<Container>(
      find.byKey(const Key('video-description-overlay')),
    );
    final actionRail = tester.widget<Container>(
      find.byKey(const Key('video-action-rail')),
    );
    expect((description.decoration! as BoxDecoration).color, isNull);
    expect((actionRail.decoration! as BoxDecoration).color, isNull);
    expect((description.decoration! as BoxDecoration).border, isNull);
    expect((actionRail.decoration! as BoxDecoration).border, isNull);
  });

  testWidgets('加入群聊按钮使用主题蓝渐变', (tester) async {
    await pumpVideoFeed(tester);

    final buttonShell = tester.widget<DecoratedBox>(
      find.byKey(const Key('join-video-group-shell-ai-workflow')),
    );
    final decoration = buttonShell.decoration as BoxDecoration;
    final gradient = decoration.gradient as LinearGradient;

    expect(gradient.colors, const [Color(0xFF7667F4), Color(0xFF5146C8)]);
    expect(decoration.borderRadius, BorderRadius.circular(12));
  });

  testWidgets('视频页右侧作者使用项目头像组件', (tester) async {
    await pumpVideoFeed(tester);

    expect(find.byType(ChatAvatar), findsOneWidget);
  });

  testWidgets('视频页不显示顶部悬浮栏', (tester) async {
    await pumpVideoFeed(tester);

    expect(find.text('像素视频'), findsNothing);
    expect(find.byKey(const Key('close-video-feed')), findsNothing);
  });

  testWidgets('视频模块支持播放控制、点赞、关注和上下切换', (tester) async {
    await pumpVideoFeed(tester);

    expect(find.byKey(const Key('vertical-video-feed')), findsOneWidget);
    expect(find.byKey(const Key('video-progress-ai-workflow')), findsOneWidget);
    final feed = tester.widget<PageView>(
      find.byKey(const Key('vertical-video-feed')),
    );
    expect(feed.childrenDelegate.estimatedChildCount, 10);
    expect(feed.allowImplicitScrolling, isTrue);
    expect(feed.scrollCacheExtent.value, 1);
    expect(feed.physics, isNot(isA<NeverScrollableScrollPhysics>()));
    expect(find.text('@Kevin AI'), findsOneWidget);
    expect(
      find.byKey(const Key('join-video-group-ai-workflow')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('video-page-ai-workflow')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('video-paused-indicator')), findsOneWidget);

    await tester.tap(find.byKey(const Key('video-like-ai-workflow')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(
        of: find.byKey(const Key('video-like-ai-workflow')),
        matching: find.byIcon(Icons.favorite_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('video-follow-ai-workflow')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.descendant(
        of: find.byKey(const Key('video-follow-ai-workflow')),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('vertical-video-feed')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(find.text('@Luna Design'), findsOneWidget);
    expect(
      find.byKey(const Key('video-progress-design-workshop')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const Key('vertical-video-feed')),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(find.text('@足球星球'), findsOneWidget);
    expect(
      find.byKey(const Key('join-video-group-football-night')),
      findsNothing,
    );
  });

  testWidgets('单次快速滑动最多切换一页', (tester) async {
    await pumpVideoFeed(tester);

    await tester.fling(
      find.byKey(const Key('vertical-video-feed')),
      const Offset(0, -1600),
      5000,
    );
    await tester.pumpAndSettle();

    expect(find.text('@Luna Design'), findsOneWidget);
    expect(find.text('@足球星球'), findsNothing);
  });

  testWidgets('视频分页不叠加上一段惯性速度', (tester) async {
    await pumpVideoFeed(tester);

    final feed = tester.widget<PageView>(
      find.byKey(const Key('vertical-video-feed')),
    );
    expect(feed.physics!.carriedMomentum(5000), 0);
  });

  testWidgets('超大距离和速度连续滑动仍逐页切换', (tester) async {
    await pumpVideoFeed(tester);

    final feedFinder = find.byKey(const Key('vertical-video-feed'));
    final feed = tester.widget<PageView>(feedFinder);
    final controller = feed.controller!;

    for (var expectedPage = 1; expectedPage <= 2; expectedPage += 1) {
      await tester.fling(feedFinder, const Offset(0, -1600), 50000);
      await tester.pumpAndSettle();
      expect(controller.page!.round(), expectedPage);
    }
  });

  testWidgets('高力度释放的回弹动画不越过相邻页', (tester) async {
    await pumpVideoFeed(tester);

    final feedFinder = find.byKey(const Key('vertical-video-feed'));
    final feed = tester.widget<PageView>(feedFinder);
    final controller = feed.controller!;

    await tester.fling(feedFinder, const Offset(0, -1600), 500000);
    for (var frame = 0; frame < 40; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller.page, lessThanOrEqualTo(1.01));
    }
  });

  testWidgets('惯性未结束时再次滑动也只推进一页', (tester) async {
    await pumpVideoFeed(tester);

    final feedFinder = find.byKey(const Key('vertical-video-feed'));
    final feed = tester.widget<PageView>(feedFinder);
    final controller = feed.controller!;

    await tester.fling(feedFinder, const Offset(0, -1600), 50000);
    await tester.pump(const Duration(milliseconds: 40));
    await tester.fling(feedFinder, const Offset(0, -1600), 50000);
    var maxPage = 0.0;
    for (var frame = 0; frame < 60; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
      final page = controller.page ?? 0;
      if (page > maxPage) maxPage = page;
    }

    expect(maxPage, lessThanOrEqualTo(2.01));
    expect(controller.page!.round(), 2);
  });

  testWidgets('单个超大拖动事件也不会越过相邻页', (tester) async {
    await pumpVideoFeed(tester);

    final feedFinder = find.byKey(const Key('vertical-video-feed'));
    final feed = tester.widget<PageView>(feedFinder);
    final controller = feed.controller!;
    final gesture = await tester.startGesture(tester.getCenter(feedFinder));
    await gesture.moveBy(const Offset(0, -1600));
    await tester.pump();

    expect(controller.page, lessThanOrEqualTo(1.01));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('视频页拖动过程中保持跟手', (tester) async {
    await pumpVideoFeed(tester);

    final feed = tester.widget<PageView>(
      find.byKey(const Key('vertical-video-feed')),
    );
    final controller = feed.controller!;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('vertical-video-feed'))),
    );
    for (var step = 0; step < 4; step += 1) {
      await gesture.moveBy(const Offset(0, -55));
      await tester.pump();
    }

    expect(controller.page, greaterThan(0.05));

    for (var step = 0; step < 12; step += 1) {
      await gesture.moveBy(const Offset(0, -100));
      await tester.pump();
    }
    expect(controller.page, lessThanOrEqualTo(1.01));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('视频支持评论和转发操作', (tester) async {
    await pumpVideoFeed(tester);

    expect(
      find.byKey(const Key('video-comment-ai-workflow')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('video-comment-ai-workflow')));
    await tester.pump();
    expect(find.byKey(const Key('video-paused-indicator')), findsNothing);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('video-comments-sheet')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('video-comment-input')),
      '这个视频很实用',
    );
    await tester.tap(find.byKey(const Key('send-video-comment')));
    await tester.pump();
    expect(find.text('这个视频很实用'), findsOneWidget);
    expect(find.text('16 条评论'), findsOneWidget);

    await tester.tap(find.byKey(const Key('close-video-comments')));
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byKey(const Key('video-share-ai-workflow')));
    await tester.pumpAndSettle();
    expect(find.text('转发到'), findsOneWidget);
    expect(find.text('好友'), findsOneWidget);
    expect(find.text('复制链接'), findsOneWidget);
    expect(find.text('保存视频'), findsOneWidget);

    await tester.tap(find.byKey(const Key('share-copy-link')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('视频链接已复制'), findsOneWidget);
  });

  testWidgets('评论展示用户头像和时间，多条回复默认折叠', (tester) async {
    await pumpVideoFeed(tester);

    await tester.tap(find.byKey(const Key('video-comment-ai-workflow')));
    await tester.pumpAndSettle();

    expect(find.text('15 条评论'), findsOneWidget);
    expect(
      find.byKey(const Key('video-comment-avatar-ai-workflow-comment-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-comment-time-ai-workflow-comment-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-comment-reply-reply-1')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('video-comment-reply-reply-2')), findsNothing);
    expect(find.text('展开剩余 2 条回复'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('expand-replies-ai-workflow-comment-0')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('video-comment-reply-reply-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('video-comment-reply-reply-3')),
      findsOneWidget,
    );
    expect(find.text('收起回复'), findsOneWidget);
  });

  testWidgets('视频评论列表使用本地头像资源组件', (tester) async {
    await pumpVideoFeed(tester);

    await tester.tap(find.byKey(const Key('video-comment-ai-workflow')));
    await tester.pumpAndSettle();

    final commentAvatar = tester.widget<ChatAvatar>(
      find.byKey(const Key('video-comment-avatar-ai-workflow-comment-0')),
    );
    final replyAvatar = tester.widget<ChatAvatar>(
      find.byKey(const Key('video-comment-reply-avatar-reply-1')),
    );
    expect(commentAvatar.name, isNotEmpty);
    expect(replyAvatar.name, 'Kevin AI');
    expect(find.byKey(const Key('video-comment-my-avatar')), findsOneWidget);
  });

  testWidgets('可回复指定评论并在该评论下展示', (tester) async {
    await pumpVideoFeed(tester);

    await tester.tap(find.byKey(const Key('video-comment-ai-workflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reply-to-ai-workflow-comment-0')));
    await tester.pump();
    expect(find.byKey(const Key('video-comment-reply-banner')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('video-comment-input')),
      '我也完成了第一版',
    );
    await tester.tap(find.byKey(const Key('send-video-comment')));
    await tester.pump();

    expect(find.byKey(const Key('video-comment-reply-banner')), findsNothing);
    expect(find.text('15 条评论'), findsOneWidget);
    expect(
      find.byKey(
        const Key('video-comment-reply-ai-workflow-comment-0-new-reply-1'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('我也完成了第一版', findRichText: true), findsOneWidget);
    expect(find.textContaining('回复 @', findRichText: true), findsWidgets);
  });

  testWidgets('抖音式评论输入支持表情、提及和图片', (tester) async {
    await pumpVideoFeed(tester);

    await tester.tap(find.byKey(const Key('video-comment-ai-workflow')));
    await tester.pumpAndSettle();
    final input = tester.widget<TextField>(
      find.byKey(const Key('video-comment-input')),
    );
    expect(input.decoration?.hintText, '礼貌评论，开心大家！');
    expect(find.byKey(const Key('video-comment-my-avatar')), findsOneWidget);

    expect(find.byKey(const Key('video-comment-mention-button')), findsNothing);
    expect(find.byKey(const Key('video-comment-emoji-button')), findsOneWidget);
    expect(find.byKey(const Key('video-comment-image-button')), findsNothing);

    await tester.tap(find.byKey(const Key('video-comment-more-button')));
    await tester.pump();
    expect(
      find.byKey(const Key('video-comment-mention-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('video-comment-image-button')), findsOneWidget);

    await tester.tap(find.byKey(const Key('video-comment-mention-button')));
    await tester.pump();
    expect(
      find.byKey(const Key('video-comment-mention-panel')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('video-mention-Kevin AI')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('video-comment-image-button')));
    await tester.pumpAndSettle();
    expect(find.text('选择评论图片'), findsOneWidget);
    await tester.tap(find.byKey(const Key('video-comment-image-option-0')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('video-comment-image-preview')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('video-comment-emoji-button')));
    await tester.pump();
    expect(find.byKey(const Key('video-comment-emoji-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('video-comment-emoji-👍')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('send-video-comment')));
    await tester.pump();
    expect(find.textContaining('@Kevin AI'), findsWidgets);
    expect(
      find.byKey(const Key('video-comment-image-ai-workflow-new-1')),
      findsOneWidget,
    );
  });

  testWidgets('视频评论输入栏复用参考草图结构', (tester) async {
    await pumpVideoFeed(tester);

    await tester.tap(find.byKey(const Key('video-comment-ai-workflow')));
    await tester.pumpAndSettle();

    final inputShell = tester.widget<Container>(
      find.byKey(const Key('video-comment-input-shell')),
    );
    final decoration = inputShell.decoration as BoxDecoration?;
    expect(decoration?.color, isNull);
    expect(inputShell.color, isNull);
    expect(decoration?.borderRadius, BorderRadius.circular(24));

    expect(find.byKey(const Key('video-comment-my-avatar')), findsOneWidget);
    expect(find.byKey(const Key('video-comment-emoji-button')), findsOneWidget);
    expect(find.byKey(const Key('video-comment-more-button')), findsOneWidget);
    expect(find.byKey(const Key('video-comment-mention-button')), findsNothing);
    expect(find.byKey(const Key('video-comment-image-button')), findsNothing);
  });

  testWidgets('视频评论输入框使用参考草图线框样式', (tester) async {
    await pumpVideoFeed(tester);

    await tester.tap(find.byKey(const Key('video-comment-ai-workflow')));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('video-comment-input')),
    );
    expect(input.decoration?.filled, isFalse);
    expect(input.decoration?.fillColor, isNull);
    expect(input.maxLines, 1);
    expect(input.decoration?.border, isA<OutlineInputBorder>());
    final border = input.decoration!.border! as OutlineInputBorder;
    expect(
      border.borderSide,
      const BorderSide(color: Color(0xFFB8B9BF), width: 2),
    );
    expect(border.borderRadius, BorderRadius.circular(24));

    final shellSize = tester.getSize(
      find.byKey(const Key('video-comment-input-shell')),
    );
    expect(shellSize.height, greaterThanOrEqualTo(40));
  });

  testWidgets('评论面板从输入框底部展开并抬升输入栏', (tester) async {
    await pumpVideoFeed(tester);

    await tester.tap(find.byKey(const Key('video-comment-ai-workflow')));
    await tester.pumpAndSettle();
    final inputShell = find.byKey(const Key('video-comment-input-shell'));
    final initialTop = tester.getTopLeft(inputShell).dy;

    await tester.tap(find.byKey(const Key('video-comment-emoji-button')));
    await tester.pumpAndSettle();
    final emojiPanel = find.byKey(const Key('video-comment-emoji-panel'));
    expect(emojiPanel, findsOneWidget);
    expect(
      tester.getRect(emojiPanel).top,
      greaterThanOrEqualTo(tester.getRect(inputShell).bottom - 1),
    );
    expect(tester.getTopLeft(inputShell).dy, lessThan(initialTop - 1));

    await tester.tap(find.byKey(const Key('video-comment-emoji-button')));
    await tester.pumpAndSettle();
    expect(emojiPanel, findsNothing);
    expect(tester.getTopLeft(inputShell).dy, closeTo(initialTop, 1));

    await tester.tap(find.byKey(const Key('video-comment-more-button')));
    await tester.pumpAndSettle();
    final toolsPanel = find.byKey(const Key('video-comment-tools-panel'));
    expect(toolsPanel, findsOneWidget);
    expect(
      tester.getRect(toolsPanel).top,
      greaterThanOrEqualTo(tester.getRect(inputShell).bottom - 1),
    );
    expect(tester.getTopLeft(inputShell).dy, lessThan(initialTop - 1));

    await tester.tap(find.byKey(const Key('video-comment-more-button')));
    await tester.pumpAndSettle();
    expect(toolsPanel, findsNothing);
    expect(tester.getTopLeft(inputShell).dy, closeTo(initialTop, 1));
  });

  testWidgets('加号工具使用带标签的创作工具卡片', (tester) async {
    await pumpVideoFeed(tester);

    await tester.tap(find.byKey(const Key('video-comment-ai-workflow')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('video-comment-more-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('video-comment-tools-panel')), findsOneWidget);
    expect(find.byKey(const Key('video-comment-mention-tile')), findsOneWidget);
    expect(find.byKey(const Key('video-comment-image-tile')), findsOneWidget);
    expect(find.text('提及好友'), findsOneWidget);
    expect(find.text('添加图片'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('video-comment-mention-tile')),
        matching: find.byIcon(Icons.alternate_email_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('video-comment-image-tile')),
        matching: find.byIcon(Icons.add_photo_alternate_rounded),
      ),
      findsOneWidget,
    );
  });

  testWidgets('右侧操作栏使用抖音式实心图标和点赞动效', (tester) async {
    await pumpVideoFeed(tester);

    final likeButton = find.byKey(const Key('video-like-ai-workflow'));
    final commentButton = find.byKey(const Key('video-comment-ai-workflow'));
    final shareButton = find.byKey(const Key('video-share-ai-workflow'));
    expect(
      find.descendant(
        of: likeButton,
        matching: find.byIcon(Icons.favorite_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: commentButton,
        matching: find.byIcon(Icons.chat_bubble_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: shareButton,
        matching: find.byIcon(Icons.reply_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(likeButton);
    await tester.pump(const Duration(milliseconds: 200));
    final likedIcon = tester.widget<Icon>(
      find.descendant(
        of: likeButton,
        matching: find.byIcon(Icons.favorite_rounded),
      ),
    );
    final likedScale = tester.widget<AnimatedScale>(
      find.descendant(of: likeButton, matching: find.byType(AnimatedScale)),
    );
    expect(likedIcon.color, const Color(0xFFFE2C55));
    expect(likedScale.scale, 1.12);
  });

  testWidgets('发布者创建群时可以从视频进入群聊', (tester) async {
    await pumpVideoFeed(tester);

    expect(
      find.byKey(const Key('join-video-group-ai-workflow')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('join-video-group-ai-workflow')));
    await tester.pumpAndSettle();

    expect(find.text('AI 视频创作者交流群'), findsOneWidget);
    expect(find.text('群公告：请遵守群规，友善交流，共同成长。'), findsOneWidget);

    await tester.pageBack();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('已加入 · 进入群聊'), findsOneWidget);
  });

  testWidgets('滑到视频列表末尾附近会追加下一页', (tester) async {
    final client = _PagedVideoClient();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: VideoFeedScreen(
          session: _SignedInSession(),
          videoApi: VideoApi(
            client: client,
            authApi: AuthApi(baseUrl: 'http://test.local'),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();

    final feed = find.byKey(const Key('vertical-video-feed'));
    expect(find.text('P1-0'), findsOneWidget);
    for (var index = 0; index < 26; index += 1) {
      await tester.drag(feed, const Offset(0, -700));
      await tester.pumpAndSettle();
    }

    expect(client.requestedPages, contains(2));
    expect(find.text('P2-0'), findsOneWidget);
    expect(find.byKey(const Key('video-load-more-end')), findsOneWidget);
  });
}

class _SignedInSession extends AuthSession {
  _SignedInSession() : super(AuthApi(baseUrl: 'http://test.local'));

  @override
  String? get accessToken => 'test-token';

  @override
  String get nickname => '测试用户';
}

class _PagedVideoClient extends http.BaseClient {
  final requestedPages = <int>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final page = int.parse(request.url.queryParameters['page'] ?? '1');
    requestedPages.add(page);
    final start = page == 1 ? 0 : 20;
    final count = page == 1
        ? 20
        : page == 2
        ? 1
        : 0;
    final data = List.generate(
      count,
      (index) => {
        'id': start + index + 1,
        'platform': 'test',
        'externalId': 'p$page-$index',
        'title': 'P$page-$index',
        'playUrl': 'https://example.com/p$page-$index.mp4',
        'likeCount': 0,
        'commentCount': 0,
        'shareCount': 0,
      },
    );
    final body = jsonEncode({'code': 0, 'message': 'ok', 'data': data});
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([utf8.encode(body)]),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}
