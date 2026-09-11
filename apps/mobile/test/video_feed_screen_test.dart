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
    final feed = tester.widget<PageView>(
      find.byKey(const Key('vertical-video-feed')),
    );
    expect(feed.childrenDelegate.estimatedChildCount, 10);
    expect(feed.allowImplicitScrolling, isTrue);
    expect(feed.scrollCacheExtent.value, 1);
    expect(feed.physics, isA<PageScrollPhysics>());
    expect(feed.physics?.parent, isA<BouncingScrollPhysics>());
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
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('@Luna Design'), findsOneWidget);

    await tester.drag(
      find.byKey(const Key('vertical-video-feed')),
      const Offset(0, -700),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('@足球星球'), findsOneWidget);
    expect(
      find.byKey(const Key('join-video-group-football-night')),
      findsNothing,
    );
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

    await tester.tap(find.byKey(const Key('video-comment-mention-button')));
    await tester.pump();
    expect(
      find.byKey(const Key('video-comment-mention-panel')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('video-mention-Kevin AI')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('video-comment-emoji-button')));
    await tester.pump();
    expect(find.byKey(const Key('video-comment-emoji-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('video-comment-emoji-👍')));
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

    await tester.tap(find.byKey(const Key('send-video-comment')));
    await tester.pump();
    expect(find.textContaining('@Kevin AI'), findsWidgets);
    expect(
      find.byKey(const Key('video-comment-image-ai-workflow-new-1')),
      findsOneWidget,
    );
  });

  testWidgets('视频评论底部输入区不设置背景色', (tester) async {
    await pumpVideoFeed(tester);

    await tester.tap(find.byKey(const Key('video-comment-ai-workflow')));
    await tester.pumpAndSettle();

    final inputShell = tester.widget<Container>(
      find.byKey(const Key('video-comment-input-shell')),
    );
    final decoration = inputShell.decoration as BoxDecoration?;
    expect(decoration?.color, isNull);
    expect(inputShell.color, isNull);
    expect(decoration?.borderRadius, BorderRadius.circular(22));
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
      await tester.pump(const Duration(milliseconds: 500));
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
