import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:video_player/video_player.dart';

import '../auth/auth_session.dart';
import '../video/video_api.dart';
import '../video/video_pagination.dart';
import '../shortdrama/short_drama_api.dart';
import '../widgets/chat_avatar.dart';
import 'group_chat_screen.dart';

const _videoInk = Color(0xFF17213A);
const _videoPurple = Color(0xFF7667F4);
const _videoCoral = Color(0xFFFE2C55);
const _videoActionRailWidth = 66.0;
const _videoActionRailRightInset = 12.0;
const _videoContentActionGap = 18.0;
const _videoOverlayBottomInset = 12.0;
const _videoPageSize = 20;

class _SinglePageScrollPhysics extends ScrollPhysics {
  const _SinglePageScrollPhysics({
    required this.startPageProvider,
    super.parent,
  });

  final int? Function() startPageProvider;

  @override
  _SinglePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SinglePageScrollPhysics(
      parent: buildParent(ancestor),
      startPageProvider: startPageProvider,
    );
  }

  @override
  double carriedMomentum(double existingVelocity) => 0;

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final adjustedOffset = super.applyPhysicsToUserOffset(position, offset);
    final startPage = startPageProvider();
    if (startPage == null || position.viewportDimension <= 0) {
      return adjustedOffset;
    }

    final viewport = position.viewportDimension;
    final minPixels = max(position.minScrollExtent, (startPage - 1) * viewport);
    final maxPixels = min(position.maxScrollExtent, (startPage + 1) * viewport);
    final candidate = position.pixels - adjustedOffset;
    if (candidate < minPixels) return position.pixels - minPixels;
    if (candidate > maxPixels) return position.pixels - maxPixels;
    return adjustedOffset;
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.viewportDimension <= 0 || position.outOfRange) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final viewport = position.viewportDimension;
    final currentPage = position.pixels / viewport;
    final velocityPage = velocity < -tolerance.velocity
        ? -0.5
        : velocity > tolerance.velocity
        ? 0.5
        : 0.0;
    var targetPage = (currentPage + velocityPage).roundToDouble();
    final startPage = startPageProvider();
    if (startPage != null) {
      targetPage = targetPage.clamp(startPage - 1, startPage + 1).toDouble();
    }
    targetPage = targetPage
        .clamp(
          position.minScrollExtent / viewport,
          position.maxScrollExtent / viewport,
        )
        .toDouble();

    final targetPixels = targetPage * viewport;
    if (targetPixels == position.pixels) return null;
    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}

class _VideoFeedItem {
  const _VideoFeedItem({
    required this.id,
    required this.author,
    required this.caption,
    required this.poster,
    required this.source,
    required this.likes,
    required this.shares,
    this.groupName,
    this.groupMembers,
    this.shortDramaId,
    this.shortDramaName,
    this.shortDramaEpisodeCount,
    this.shortDramaEpisodeTitle,
    this.shortDramaEpisodeUrl,
  });

  final String id;
  final String author;
  final String caption;
  final String poster;
  final String source;
  final int likes;
  final int shares;
  final String? groupName;
  final String? groupMembers;
  final int? shortDramaId;
  final String? shortDramaName;
  final int? shortDramaEpisodeCount;
  final String? shortDramaEpisodeTitle;
  final String? shortDramaEpisodeUrl;

  bool get isShortDrama => shortDramaId != null;
}

class _VideoComment {
  _VideoComment({
    required this.id,
    required this.author,
    required this.content,
    required this.time,
    required this.avatarColor,
    this.imageAsset,
    List<_VideoCommentReply>? replies,
  }) : replies = replies ?? [];

  final String id;
  final String author;
  final String content;
  final String time;
  final Color avatarColor;
  final String? imageAsset;
  final List<_VideoCommentReply> replies;
}

class _VideoCommentReply {
  const _VideoCommentReply({
    required this.id,
    required this.author,
    required this.content,
    required this.time,
    required this.avatarColor,
    this.replyTo,
    this.imageAsset,
  });

  final String id;
  final String author;
  final String content;
  final String time;
  final Color avatarColor;
  final String? replyTo;
  final String? imageAsset;
}

class _CommentReplyTarget {
  const _CommentReplyTarget({required this.comment, required this.user});

  final _VideoComment comment;
  final String user;
}

const _videoItems = <_VideoFeedItem>[
  _VideoFeedItem(
    id: 'ai-workflow',
    author: 'Kevin AI',
    caption: '忙里偷闲看看社区的最新消息 #日常 #社交',
    poster: 'assets/images/ai-video-workflow.png',
    source: 'assets/videos/douyin-style-01.mp4',
    likes: 12580,
    shares: 986,
    groupName: 'AI 视频创作者交流群',
    groupMembers: '2,856',
  ),
  _VideoFeedItem(
    id: 'design-workshop',
    author: 'Luna Design',
    caption: '聊天表情的正确打开方式 #手机 #生活记录',
    poster: 'assets/images/community-design-collaboration.png',
    source: 'assets/videos/douyin-style-02.mp4',
    likes: 8632,
    shares: 521,
    groupName: '产品设计交流社区',
    groupMembers: '18,420',
  ),
  _VideoFeedItem(
    id: 'football-night',
    author: '足球星球',
    caption: '咖啡店里回复今天的第一条消息 #城市生活',
    poster: 'assets/images/community-design-match.jpg',
    source: 'assets/videos/douyin-style-03.mp4',
    likes: 24300,
    shares: 1820,
  ),
  _VideoFeedItem(
    id: 'event-poster',
    author: '活动实验室',
    caption: '咖啡和音乐，开启元气满满的一天 #早安',
    poster: 'assets/images/community-design-lucky-king.jpg',
    source: 'assets/videos/douyin-style-04.mp4',
    likes: 9716,
    shares: 734,
    groupName: '活动运营共创群',
    groupMembers: '6,318',
  ),
  _VideoFeedItem(
    id: 'creator-camera',
    author: '七喜',
    caption: '镜头背后的创作现场，原来是这样的 #幕后',
    poster: 'assets/images/ai-video-workflow.png',
    source: 'assets/videos/douyin-style-05.mp4',
    likes: 15766,
    shares: 1102,
  ),
  _VideoFeedItem(
    id: 'selfie-moment',
    author: 'Nora Studio',
    caption: '今天也要记录一个开心的瞬间 #自拍 #日常',
    poster: 'assets/images/community-design-collaboration.png',
    source: 'assets/videos/douyin-style-06.mp4',
    likes: 28641,
    shares: 2046,
  ),
  _VideoFeedItem(
    id: 'cleaning-dance',
    author: 'Mia Growth',
    caption: '把做家务变成一场居家舞会 #舞蹈 #生活',
    poster: 'assets/images/community-design-match.jpg',
    source: 'assets/videos/douyin-style-07.mp4',
    likes: 34820,
    shares: 3217,
    groupName: '生活短视频共创群',
    groupMembers: '9,672',
  ),
  _VideoFeedItem(
    id: 'vlogger-story',
    author: '林木 Design',
    caption: '面对镜头讲好一个故事的三个要点 #Vlog',
    poster: 'assets/images/community-design-lucky-king.jpg',
    source: 'assets/videos/douyin-style-08.mp4',
    likes: 11360,
    shares: 875,
  ),
  _VideoFeedItem(
    id: 'studio-vlog',
    author: 'Ada Product',
    caption: '我的第一次工作室 Vlog，真实比完美更重要 #创作',
    poster: 'assets/images/ai-video-workflow.png',
    source: 'assets/videos/douyin-style-09.mp4',
    likes: 19437,
    shares: 1439,
    groupName: 'Vlog 创作交流群',
    groupMembers: '5,231',
  ),
  _VideoFeedItem(
    id: 'coffee-dance',
    author: '阿北摄影',
    caption: '一杯咖啡的时间，让心情跟着音乐动起来 #治愈',
    poster: 'assets/images/community-design-collaboration.png',
    source: 'assets/videos/douyin-style-10.mp4',
    likes: 22618,
    shares: 1678,
  ),
];

const _commentAuthors = [
  '一颗柚子',
  'Mia UX',
  '阿杰',
  '小宇',
  'Pixel Lab',
  '北城光影',
  'Nora Studio',
  '七喜',
  'Ada Product',
  '林木 Design',
  '阿北摄影',
  '小鹿同学',
  'Kevin Fan',
  '晚风',
  '创作日记',
];

const _commentContents = [
  '这个流程讲得很清楚，已经跟着做了一遍！',
  '第三步的细节很有用，可以单独出一期吗？',
  '这是我按视频方法做的效果，比之前顺多了。',
  '一直想找这种不绕弯的教程。',
  '收藏了，周末照着完整实践一次。',
  '节奏很舒服，信息量也刚刚好。',
  '我把页面层级也重新整理了，大家可以看看。',
  '新手也能听懂，感谢分享。',
  '有没有同学一起打卡练习？',
  '关键帧部分我试了两遍，第二遍就顺了。',
  '这种用真实案例讲解的方式很好。',
  '我的练习图在这里，欢迎大家提建议。',
  '讲解很细，连容易踩坑的地方都提到了。',
  '建议下期增加一个前后效果对比。',
  '今天最有收获的一条视频，谢谢创作者。',
];

const _commentTimes = [
  '2分钟前',
  '8分钟前',
  '18分钟前',
  '32分钟前',
  '1小时前',
  '2小时前',
  '3小时前',
  '5小时前',
  '今天 09:42',
  '今天 08:16',
  '昨天 23:08',
  '昨天 20:35',
  '昨天 18:21',
  '昨天 15:04',
  '09-06',
];

const _commentAvatarColors = [
  Color(0xFFEF6C75),
  Color(0xFF6B7CE3),
  Color(0xFF39A88E),
  Color(0xFFE2973B),
  Color(0xFF8A64D6),
  Color(0xFF4E8CC8),
];

List<_VideoComment> _buildSampleComments(String videoId) {
  final offset = videoId.codeUnits.fold<int>(0, (sum, value) => sum + value);
  final contentOrder = List<int>.generate(
    _commentContents.length,
    (index) => index,
  )..shuffle(Random(offset));
  return List<_VideoComment>.generate(15, (index) {
    final author = _commentAuthors[(index + offset) % _commentAuthors.length];
    final imageAsset = switch (index) {
      2 => 'assets/images/community-design-collaboration.png',
      6 => 'assets/images/ai-video-workflow.png',
      11 => 'assets/images/community-design-match.jpg',
      _ => null,
    };
    final replies = <_VideoCommentReply>[];
    if (index == 0) {
      replies.addAll([
        const _VideoCommentReply(
          id: 'reply-1',
          author: 'Kevin AI',
          content: '谢谢，完成后也可以发到群里一起交流。',
          time: '1分钟前',
          avatarColor: Color(0xFF6A5CFF),
        ),
        _VideoCommentReply(
          id: 'reply-2',
          author: '小鹿同学',
          content: '我也试了，效果真的不错。',
          time: '3分钟前',
          avatarColor: _commentAvatarColors[4],
          replyTo: author,
        ),
        const _VideoCommentReply(
          id: 'reply-3',
          author: 'Mia UX',
          content: '坐等你的实践作品！',
          time: '5分钟前',
          avatarColor: Color(0xFF39A88E),
        ),
      ]);
    } else if (index == 4) {
      replies.addAll([
        const _VideoCommentReply(
          id: 'reply-4',
          author: '阿杰',
          content: '可以加我，我也在练习。',
          time: '36分钟前',
          avatarColor: Color(0xFFE2973B),
        ),
        const _VideoCommentReply(
          id: 'reply-5',
          author: '七喜',
          content: '我们可以组个小组。',
          time: '31分钟前',
          avatarColor: Color(0xFFEF6C75),
        ),
      ]);
    }
    return _VideoComment(
      id: '$videoId-comment-$index',
      author: author,
      content: _commentContents[contentOrder[index]],
      time: _commentTimes[index],
      avatarColor: _commentAvatarColors[(index + offset) % 6],
      imageAsset: imageAsset,
      replies: replies,
    );
  });
}

class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({
    super.key,
    required this.session,
    this.videoApi,
    this.showBackButton = true,
    this.initialIndex = 0,
  });

  final AuthSession session;
  final VideoApi? videoApi;
  final bool showBackButton;
  final int initialIndex;

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

int? shortDramaNextEpisodeIndex({
  required int currentIndex,
  required int totalEpisodes,
  required Duration position,
  required Duration duration,
  required bool isPlaying,
}) {
  if (isPlaying || duration <= Duration.zero) return null;
  if (currentIndex < 0 || currentIndex + 1 >= totalEpisodes) return null;
  return position >= duration ? currentIndex + 1 : null;
}

String? shortDramaVideoDescription({
  required bool isShortDrama,
  required String caption,
}) => isShortDrama ? null : caption;

class ShortDramaFeedScreen extends StatefulWidget {
  const ShortDramaFeedScreen({
    super.key,
    required this.session,
    required this.drama,
    required this.api,
  });

  final AuthSession session;
  final ShortDramaData drama;
  final ShortDramaApi api;

  @override
  State<ShortDramaFeedScreen> createState() => _ShortDramaFeedScreenState();
}

class _ShortDramaFeedScreenState extends State<ShortDramaFeedScreen> {
  late final PageController pageController;
  late final _SinglePageScrollPhysics pagePhysics;
  final controllers = <int, VideoPlayerController>{};
  final initializing = <int, Future<void>>{};
  int currentIndex = 0;
  int? activeDragStartPage;
  int? autoAdvancingFrom;
  bool paused = false;
  bool failed = false;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    pagePhysics = _SinglePageScrollPhysics(
      parent: const BouncingScrollPhysics(),
      startPageProvider: () => activeDragStartPage,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => prepareAround(0));
  }

  @override
  void dispose() {
    pageController.dispose();
    for (final controller in controllers.values) {
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  Future<void> initializeEpisode(int index) async {
    if (index < 0 || index >= widget.drama.episodes.length) return;
    final episode = widget.drama.episodes[index];
    var source = episode.m3u8Url;
    final token = widget.session.accessToken;
    if (index == currentIndex && token != null && token.isNotEmpty) {
      try {
        final refreshed = (await widget.api.playUrl(
          token,
          widget.drama.id,
          index + 1,
        )).url;
        if (refreshed.isNotEmpty) source = refreshed;
      } catch (_) {
        if (source.isEmpty && mounted && index == currentIndex) {
          setState(() => failed = true);
        }
      }
    }
    if (source.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(Uri.parse(source));
    controllers[index] = controller;
    try {
      await controller.initialize();
      if (!mounted || (index - currentIndex).abs() > 1) {
        controllers.remove(index);
        await controller.dispose();
        return;
      }
      await controller.setLooping(false);
      await controller.pause();
      controller.addListener(() {
        if (!mounted || index != currentIndex) return;
        final value = controller.value;
        final nextIndex = shortDramaNextEpisodeIndex(
          currentIndex: index,
          totalEpisodes: widget.drama.episodes.length,
          position: value.position,
          duration: value.duration,
          isPlaying: value.isPlaying,
        );
        if (nextIndex == null || autoAdvancingFrom == index) return;
        autoAdvancingFrom = index;
        unawaited(_advanceToEpisode(nextIndex, index));
      });
      if (mounted && index == currentIndex) {
        setState(() => failed = false);
        unawaited(playEpisode(index));
      }
    } catch (_) {
      if (identical(controllers[index], controller)) controllers.remove(index);
      await controller.dispose();
      if (mounted && index == currentIndex) setState(() => failed = true);
    }
  }

  Future<void> ensureEpisodeReady(int index) {
    if (index < 0 || index >= widget.drama.episodes.length) {
      return Future<void>.value();
    }
    final existing = controllers[index];
    if (existing?.value.isInitialized == true) return Future<void>.value();
    final pending = initializing[index];
    if (pending != null) return pending;
    late final Future<void> task;
    task = initializeEpisode(index).whenComplete(() {
      if (identical(initializing[index], task)) initializing.remove(index);
    });
    initializing[index] = task;
    return task;
  }

  Future<void> playEpisode(int index) async {
    if (!mounted || index != currentIndex || paused) return;
    final controller = controllers[index];
    if (controller?.value.isInitialized != true) return;
    await controller!.play();
  }

  Future<void> _advanceToEpisode(int nextIndex, int fromIndex) async {
    try {
      if (mounted) {
        await pageController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      }
    } finally {
      if (autoAdvancingFrom == fromIndex) autoAdvancingFrom = null;
    }
  }

  Future<void> prepareAround(int index) async {
    final pauses = <Future<void>>[];
    for (final entry in controllers.entries) {
      if (entry.key != index && entry.value.value.isInitialized) {
        pauses.add(entry.value.pause());
      }
    }
    if (pauses.isNotEmpty) await Future.wait(pauses);
    await ensureEpisodeReady(index);
    await playEpisode(index);
    unawaited(ensureEpisodeReady(index - 1));
    unawaited(ensureEpisodeReady(index + 1));
    for (final cachedIndex in controllers.keys.toList()) {
      if ((cachedIndex - index).abs() <= 1 ||
          initializing.containsKey(cachedIndex)) {
        continue;
      }
      final controller = controllers.remove(cachedIndex);
      if (controller != null) unawaited(controller.dispose());
    }
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      final viewport = notification.metrics.viewportDimension;
      activeDragStartPage = viewport > 0
          ? (notification.metrics.pixels / viewport).round()
          : currentIndex;
    } else if (notification is ScrollEndNotification) {
      activeDragStartPage = null;
    }
    return false;
  }

  void togglePlayback() {
    final controller = controllers[currentIndex];
    setState(() => paused = !paused);
    if (controller?.value.isInitialized != true) return;
    paused ? unawaited(controller!.pause()) : unawaited(controller!.play());
  }

  void showEpisodePicker() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _ShortDramaEpisodePicker(
        drama: widget.drama,
        currentIndex: currentIndex,
        onSelected: (index) {
          Navigator.pop(sheetContext);
          if (index == currentIndex) return;
          setState(() {
            paused = false;
            failed = false;
          });
          if (pageController.hasClients) pageController.jumpToPage(index);
        },
      ),
    );
  }

  Widget buildEpisodeLayer(int index) {
    final episode = widget.drama.episodes[index];
    final controller = controllers[index];
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: Image.asset(
            'assets/images/community-design-collaboration.png',
            fit: BoxFit.cover,
            semanticLabel: '${widget.drama.name}第${episode.episode}集封面',
          ),
        ),
        if (controller?.value.isInitialized == true)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller!.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        if (index == currentIndex && failed)
          const Center(
            child: Text(
              '本集暂时无法播放',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final episode = widget.drama.episodes[currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      body: NotificationListener<ScrollNotification>(
        onNotification: handleScrollNotification,
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              key: const Key('short-drama-vertical-feed'),
              controller: pageController,
              scrollDirection: Axis.vertical,
              pageSnapping: false,
              allowImplicitScrolling: true,
              physics: pagePhysics,
              itemCount: widget.drama.episodes.length,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                  paused = false;
                  failed = false;
                });
                prepareAround(index);
              },
              itemBuilder: (context, index) => GestureDetector(
                key: Key(
                  'short-drama-episode-${widget.drama.episodes[index].episode}',
                ),
                behavior: HitTestBehavior.opaque,
                onTap: togglePlayback,
                child: IgnorePointer(child: buildEpisodeLayer(index)),
              ),
            ),
            if (paused)
              IgnorePointer(
                child: Center(
                  child: Container(
                    key: const Key('short-drama-playback-indicator'),
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      color: const Color(0xFF17213A).withValues(alpha: 0.72),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 12,
              top: MediaQuery.paddingOf(context).top + 8,
              child: IconButton(
                key: const Key('short-drama-back'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                tooltip: '返回视频',
              ),
            ),
            Positioned(
              left: 60,
              top: MediaQuery.paddingOf(context).top + 17,
              right: 56,
              child: Text(
                widget.drama.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 82,
              bottom: bottom + 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.drama.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '第 ${episode.episode} 集 / 共 ${widget.drama.totalEpisodes} 集',
                        key: const Key('short-drama-episode-progress'),
                        style: const TextStyle(
                          color: Color(0xFF95C8F4),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        key: const Key('short-drama-episode-picker'),
                        onTap: showEpisodePicker,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            child: Text(
                              '选集',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentIndex == widget.drama.episodes.length - 1
                        ? '已播放全部剧集'
                        : '上滑播放下一集',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 14,
              bottom: bottom + 24,
              child: Column(
                children: [
                  _ShortDramaAction(
                    icon: Icons.favorite_border_rounded,
                    label: '喜欢',
                  ),
                  const SizedBox(height: 18),
                  _ShortDramaAction(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: '评论',
                  ),
                  const SizedBox(height: 18),
                  _ShortDramaAction(icon: Icons.ios_share_rounded, label: '分享'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortDramaEpisodePicker extends StatelessWidget {
  const _ShortDramaEpisodePicker({
    required this.drama,
    required this.currentIndex,
    required this.onSelected,
  });

  final ShortDramaData drama;
  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.62,
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      drama.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF17213A),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '共 ${drama.totalEpisodes} 集',
                      style: const TextStyle(
                        color: Color(0xFF7D8799),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: const Key('short-drama-picker-close'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                color: const Color(0xFF4E5870),
                tooltip: '关闭选集',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              key: const Key('short-drama-episode-grid'),
              padding: const EdgeInsets.only(bottom: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 2.25,
              ),
              itemCount: drama.episodes.length,
              itemBuilder: (context, index) {
                final episode = drama.episodes[index];
                final selected = index == currentIndex;
                return InkWell(
                  key: Key('short-drama-episode-choice-${episode.episode}'),
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(12),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF95C8F4) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF5AA5E8)
                            : const Color(0xFFE3E8F1),
                      ),
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selected)
                            Padding(
                              padding: EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.check_rounded,
                                key: Key(
                                  'short-drama-selected-episode-${episode.episode}',
                                ),
                                size: 16,
                                color: Color(0xFF17213A),
                              ),
                            ),
                          Text(
                            '第 ${episode.episode} 集',
                            style: TextStyle(
                              color: selected
                                  ? const Color(0xFF17213A)
                                  : const Color(0xFF3E4961),
                              fontSize: 13,
                              fontWeight: selected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _ShortDramaAction extends StatelessWidget {
  const _ShortDramaAction({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: Colors.white, size: 28),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late List<_VideoFeedItem> videoItems;
  late final VideoApi videoApi;
  late final ShortDramaApi shortDramaApi;
  late final VideoPagination remotePagination;
  late final PageController pageController;
  late final _SinglePageScrollPhysics pagePhysics;
  final commentInput = TextEditingController();
  final commentFocusNode = FocusNode();
  final likedVideos = <String>{};
  final followedCreators = <String>{};
  final joinedGroups = <String>{};
  final shortDramas = <int, ShortDramaData>{};
  final comments = <String, List<_VideoComment>>{};
  final videoControllers = <int, VideoPlayerController>{};
  final initializingVideos = <int, Future<void>>{};
  final loadingVideos = <int>{};
  final failedVideos = <int>{};
  late int currentIndex;
  bool remoteFeedReady = false;
  bool loadingMore = false;
  bool loadMoreFailed = false;
  bool paused = false;
  bool showLikeBurst = false;
  int? activeDragStartPage;
  int commentSequence = 0;

  VideoPlayerController? get currentController =>
      videoControllers[currentIndex];

  @override
  void initState() {
    super.initState();
    videoItems = List<_VideoFeedItem>.of(_videoItems);
    videoApi = widget.videoApi ?? VideoApi();
    shortDramaApi = ShortDramaApi();
    final token = widget.session.accessToken ?? '';
    remotePagination = VideoPagination(
      pageSize: _videoPageSize,
      fetchPage: (page, pageSize) =>
          videoApi.list(token, page: page, pageSize: pageSize),
    );
    currentIndex = widget.initialIndex.clamp(0, videoItems.length - 1);
    pageController = PageController(initialPage: currentIndex);
    pagePhysics = _SinglePageScrollPhysics(
      parent: const BouncingScrollPhysics(),
      startPageProvider: () => activeDragStartPage,
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => prepareAround(currentIndex),
    );
    unawaited(loadRemoteVideos());
  }

  Future<void> loadRemoteVideos() async {
    final token = widget.session.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final remoteVideos = await remotePagination.loadNext();
      if (!mounted) return;
      if (remoteVideos.isEmpty) {
        unawaited(loadRemoteShortDramas());
        return;
      }
      final mapped = mapRemoteVideos(remoteVideos, 0);
      for (final controller in videoControllers.values) {
        unawaited(controller.dispose());
      }
      videoControllers.clear();
      initializingVideos.clear();
      loadingVideos.clear();
      failedVideos.clear();
      comments.clear();
      setState(() {
        videoItems = mapped;
        currentIndex = currentIndex.clamp(0, videoItems.length - 1);
        remoteFeedReady = true;
        loadMoreFailed = false;
        paused = false;
      });
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => prepareAround(currentIndex),
      );
    } catch (_) {
      // Keep local examples when the API is unavailable.
    }
    unawaited(loadRemoteShortDramas());
  }

  Future<void> loadRemoteShortDramas() async {
    final token = widget.session.accessToken;
    if (token == null || token.isEmpty) return;
    try {
      final dramas = await shortDramaApi.list(token, pageSize: 10);
      if (!mounted) return;
      final items = <_VideoFeedItem>[];
      for (final drama in dramas) {
        if (drama.episodes.isEmpty) continue;
        final first = drama.episodes.first;
        items.add(
          _VideoFeedItem(
            id: 'short-drama-${drama.id}',
            author: '短剧创作实验室',
            caption: first.title,
            poster: 'assets/images/community-design-collaboration.png',
            source: first.m3u8Url,
            likes: 0,
            shares: 0,
            shortDramaId: drama.id,
            shortDramaName: drama.name,
            shortDramaEpisodeCount: drama.totalEpisodes,
            shortDramaEpisodeTitle: first.title,
            shortDramaEpisodeUrl: first.m3u8Url,
          ),
        );
      }
      if (items.isEmpty) return;
      setState(() {
        shortDramas
          ..clear()
          ..addEntries(dramas.map((drama) => MapEntry(drama.id, drama)));
        videoItems.removeWhere((item) => item.isShortDrama);
        videoItems.addAll(items);
      });
    } catch (_) {
      // Keep the regular video feed when short-drama data is unavailable.
    }
  }

  List<_VideoFeedItem> mapRemoteVideos(
    List<PlatformVideoData> remoteVideos,
    int fallbackOffset,
  ) {
    return remoteVideos.asMap().entries.map((entry) {
      final item = entry.value;
      final fallback =
          _videoItems[(fallbackOffset + entry.key) % _videoItems.length];
      return _VideoFeedItem(
        id: '${item.platform}-${item.externalId}',
        author: item.platform == 'douyin'
            ? '抖音热门'
            : '${item.platform.toUpperCase()} 热门',
        caption: item.title,
        poster: fallback.poster,
        source: item.playUrl,
        likes: item.likeCount,
        shares: item.shareCount,
      );
    }).toList();
  }

  Future<void> loadMoreVideos() async {
    if (!remoteFeedReady || loadingMore || !remotePagination.hasMore) return;
    setState(() {
      loadingMore = true;
      loadMoreFailed = false;
    });
    try {
      final remoteVideos = await remotePagination.loadNext();
      if (!mounted) return;
      final mapped = mapRemoteVideos(remoteVideos, videoItems.length);
      setState(() {
        videoItems.addAll(mapped);
        loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loadingMore = false;
        loadMoreFailed = true;
      });
    }
  }

  @override
  void dispose() {
    pageController.dispose();
    commentInput.dispose();
    commentFocusNode.dispose();
    for (final controller in videoControllers.values) {
      unawaited(controller.dispose());
    }
    videoControllers.clear();
    super.dispose();
  }

  Future<void> initializeVideo(int index) async {
    loadingVideos.add(index);
    failedVideos.remove(index);
    if (mounted) setState(() {});
    final source = videoItems[index].source;
    final controller = source.startsWith('assets/')
        ? VideoPlayerController.asset(source)
        : VideoPlayerController.networkUrl(Uri.parse(source));
    videoControllers[index] = controller;
    try {
      await controller.initialize();
      if (!mounted || (index - currentIndex).abs() > 1) {
        if (identical(videoControllers[index], controller)) {
          videoControllers.remove(index);
        }
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.seekTo(Duration.zero);
      await controller.pause();
      loadingVideos.remove(index);
      failedVideos.remove(index);
      if (mounted) setState(() {});
    } catch (_) {
      if (identical(videoControllers[index], controller)) {
        videoControllers.remove(index);
      }
      loadingVideos.remove(index);
      failedVideos.add(index);
      await controller.dispose();
      if (mounted) setState(() {});
    }
  }

  Future<void> ensureVideoReady(int index) {
    if (index < 0 || index >= videoItems.length) {
      return Future<void>.value();
    }
    final controller = videoControllers[index];
    if (controller?.value.isInitialized == true) {
      return Future<void>.value();
    }
    final pending = initializingVideos[index];
    if (pending != null) return pending;

    late final Future<void> task;
    task = initializeVideo(index).whenComplete(() {
      if (identical(initializingVideos[index], task)) {
        initializingVideos.remove(index);
      }
    });
    initializingVideos[index] = task;
    return task;
  }

  void prepareAround(int index) {
    for (final entry in videoControllers.entries) {
      if (entry.key != index && entry.value.value.isInitialized) {
        unawaited(entry.value.pause());
      }
    }

    unawaited(
      ensureVideoReady(index).then((_) {
        final controller = videoControllers[index];
        if (mounted &&
            currentIndex == index &&
            !paused &&
            controller?.value.isInitialized == true) {
          unawaited(controller!.play());
        }
      }),
    );
    unawaited(ensureVideoReady(index - 1));
    unawaited(ensureVideoReady(index + 1));

    for (final cachedIndex in videoControllers.keys.toList()) {
      if ((cachedIndex - index).abs() <= 1 ||
          initializingVideos.containsKey(cachedIndex)) {
        continue;
      }
      final controller = videoControllers.remove(cachedIndex);
      if (controller != null) unawaited(controller.dispose());
    }
  }

  void togglePlayback() {
    setState(() => paused = !paused);
    final controller = currentController;
    if (controller == null || !controller.value.isInitialized) {
      if (!paused && failedVideos.contains(currentIndex)) {
        failedVideos.remove(currentIndex);
        prepareAround(currentIndex);
      }
      return;
    }
    paused ? controller.pause() : controller.play();
  }

  bool handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      final page = notification.metrics.viewportDimension > 0
          ? notification.metrics.pixels / notification.metrics.viewportDimension
          : currentIndex.toDouble();
      activeDragStartPage = page.round();
    } else if (notification is ScrollEndNotification) {
      activeDragStartPage = null;
    }
    return false;
  }

  void pauseForOverlay() {
    final controller = currentController;
    if (controller?.value.isInitialized == true) {
      unawaited(controller!.pause());
    }
  }

  Future<void> pauseForOverlayAndWait() async {
    final controller = currentController;
    if (controller?.value.isInitialized == true) {
      await controller!.pause();
    }
  }

  void resumeAfterOverlay() {
    final controller = currentController;
    if (!paused && controller?.value.isInitialized == true) {
      unawaited(controller!.play());
    }
  }

  void toggleLike(_VideoFeedItem video, {bool showBurst = false}) {
    setState(() {
      if (showBurst) {
        likedVideos.add(video.id);
        showLikeBurst = true;
      } else if (!likedVideos.add(video.id)) {
        likedVideos.remove(video.id);
      }
    });
    if (showBurst) {
      Future<void>.delayed(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => showLikeBurst = false);
      });
    }
  }

  String compactCount(int value) {
    if (value >= 10000) {
      final count = value / 10000;
      return '${count.toStringAsFixed(count >= 10 ? 1 : 2)}万';
    }
    return value.toString();
  }

  void appendCommentText(String value) {
    final nextText = '${commentInput.text}$value';
    commentInput.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
    );
  }

  Future<void> openComments(_VideoFeedItem video) async {
    pauseForOverlay();
    commentInput.clear();
    final expandedComments = <String>{};
    _CommentReplyTarget? replyTarget;
    String? pendingImage;
    var showTools = false;
    var showEmojiPanel = false;
    var showMentionPanel = false;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final videoComments = comments.putIfAbsent(
            video.id,
            () => _buildSampleComments(video.id),
          );
          final hasDraft =
              commentInput.text.trim().isNotEmpty || pendingImage != null;
          return DraggableScrollableSheet(
            key: const Key('video-comments-sheet'),
            initialChildSize: 0.78,
            minChildSize: 0.45,
            maxChildSize: 0.94,
            expand: false,
            builder: (context, scrollController) => Container(
              decoration: const BoxDecoration(
                color: Color(0xFFF7F7FB),
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${videoComments.length} 条评论',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          key: const Key('close-video-comments'),
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                      itemCount: videoComments.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 22),
                      itemBuilder: (context, index) {
                        final comment = videoComments[index];
                        return _VideoCommentTile(
                          key: Key('video-comment-item-${comment.id}'),
                          comment: comment,
                          expanded: expandedComments.contains(comment.id),
                          onToggleReplies: () => setSheetState(() {
                            if (!expandedComments.add(comment.id)) {
                              expandedComments.remove(comment.id);
                            }
                          }),
                          onReply: (user) {
                            setSheetState(() {
                              replyTarget = _CommentReplyTarget(
                                comment: comment,
                                user: user,
                              );
                              showEmojiPanel = false;
                              showMentionPanel = false;
                            });
                            commentFocusNode.requestFocus();
                          },
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  SafeArea(
                    top: false,
                    child: AnimatedPadding(
                      duration: const Duration(milliseconds: 120),
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.viewInsetsOf(context).bottom,
                      ),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                        child: AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.bottomCenter,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (replyTarget != null)
                                Container(
                                  key: const Key('video-comment-reply-banner'),
                                  margin: const EdgeInsets.only(bottom: 7),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 7,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF5F5F7),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          '回复 @${replyTarget!.user}',
                                          style: const TextStyle(
                                            color: Color(0xFF676975),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      GestureDetector(
                                        key: const Key(
                                          'cancel-video-comment-reply',
                                        ),
                                        onTap: () => setSheetState(
                                          () => replyTarget = null,
                                        ),
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 17,
                                          color: Color(0xFF8B8D96),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (pendingImage != null)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.asset(
                                          pendingImage!,
                                          key: const Key(
                                            'video-comment-image-preview',
                                          ),
                                          width: 62,
                                          height: 62,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      Positioned(
                                        right: -7,
                                        top: -7,
                                        child: GestureDetector(
                                          key: const Key(
                                            'remove-video-comment-image',
                                          ),
                                          onTap: () => setSheetState(
                                            () => pendingImage = null,
                                          ),
                                          child: const CircleAvatar(
                                            radius: 9,
                                            backgroundColor: Color(0xFF555760),
                                            child: Icon(
                                              Icons.close_rounded,
                                              size: 12,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (pendingImage != null)
                                const SizedBox(height: 7),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  ChatAvatar.person(
                                    key: const Key('video-comment-my-avatar'),
                                    name: widget.session.nickname,
                                    radius: 17,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      key: const Key(
                                        'video-comment-input-shell',
                                      ),
                                      constraints: const BoxConstraints(
                                        minHeight: 44,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              key: const Key(
                                                'video-comment-input',
                                              ),
                                              controller: commentInput,
                                              focusNode: commentFocusNode,
                                              minLines: 1,
                                              maxLines: 1,
                                              textInputAction:
                                                  TextInputAction.newline,
                                              onChanged: (_) =>
                                                  setSheetState(() {}),
                                              cursorColor: _videoPurple,
                                              style: const TextStyle(
                                                color: Color(0xFF202231),
                                                fontSize: 14,
                                                height: 1.25,
                                              ),
                                              decoration: InputDecoration(
                                                hintText: '礼貌评论，开心大家！',
                                                hintStyle: const TextStyle(
                                                  color: Color(0xFF9295A1),
                                                  fontSize: 14,
                                                  height: 1.25,
                                                ),
                                                isDense: true,
                                                filled: false,
                                                contentPadding:
                                                    const EdgeInsets.fromLTRB(
                                                      18,
                                                      10,
                                                      18,
                                                      10,
                                                    ),
                                                border:
                                                    const OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Color(
                                                          0xFFB8B9BF,
                                                        ),
                                                        width: 2,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.all(
                                                            Radius.circular(24),
                                                          ),
                                                    ),
                                                enabledBorder:
                                                    const OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Color(
                                                          0xFFB8B9BF,
                                                        ),
                                                        width: 2,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.all(
                                                            Radius.circular(24),
                                                          ),
                                                    ),
                                                focusedBorder:
                                                    const OutlineInputBorder(
                                                      borderSide: BorderSide(
                                                        color: Color(
                                                          0xFF635BFF,
                                                        ),
                                                        width: 2,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.all(
                                                            Radius.circular(24),
                                                          ),
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  _CommentInputAction(
                                    key: const Key(
                                      'video-comment-emoji-button',
                                    ),
                                    tooltip: '表情',
                                    icon: Icons.sentiment_satisfied_alt_rounded,
                                    iconColor: Colors.white,
                                    backgroundColor: const Color(0xFF101116),
                                    onPressed: () => setSheetState(() {
                                      showEmojiPanel = !showEmojiPanel;
                                      showTools = false;
                                      showMentionPanel = false;
                                    }),
                                  ),
                                  const SizedBox(width: 4),
                                  Semantics(
                                    key: const Key('video-comment-more-button'),
                                    button: true,
                                    label: hasDraft
                                        ? '发送评论'
                                        : showTools
                                        ? '收起功能'
                                        : '更多功能',
                                    child: IconButton(
                                      key: const Key('send-video-comment'),
                                      padding: EdgeInsets.zero,
                                      constraints:
                                          const BoxConstraints.tightFor(
                                            width: 40,
                                            height: 40,
                                          ),
                                      onPressed: () {
                                        final draftExists =
                                            commentInput.text
                                                .trim()
                                                .isNotEmpty ||
                                            pendingImage != null;
                                        if (!draftExists) {
                                          setSheetState(() {
                                            showTools = !showTools;
                                            showEmojiPanel = false;
                                            showMentionPanel = false;
                                          });
                                          return;
                                        }
                                        final value = commentInput.text.trim();
                                        final target = replyTarget;
                                        final author = widget.session.nickname
                                            .trim();
                                        final displayAuthor = author.isEmpty
                                            ? '我'
                                            : author;
                                        commentSequence += 1;
                                        setSheetState(() {
                                          if (target == null) {
                                            videoComments.insert(
                                              0,
                                              _VideoComment(
                                                id: '${video.id}-new-$commentSequence',
                                                author: displayAuthor,
                                                content: value,
                                                time: '刚刚',
                                                avatarColor: const Color(
                                                  0xFF6A5CFF,
                                                ),
                                                imageAsset: pendingImage,
                                              ),
                                            );
                                          } else {
                                            target.comment.replies.insert(
                                              0,
                                              _VideoCommentReply(
                                                id: '${target.comment.id}-new-reply-$commentSequence',
                                                author: displayAuthor,
                                                content: value,
                                                time: '刚刚',
                                                avatarColor: const Color(
                                                  0xFF6A5CFF,
                                                ),
                                                replyTo: target.user,
                                                imageAsset: pendingImage,
                                              ),
                                            );
                                            expandedComments.add(
                                              target.comment.id,
                                            );
                                          }
                                          replyTarget = null;
                                          pendingImage = null;
                                          showEmojiPanel = false;
                                          showMentionPanel = false;
                                          showTools = false;
                                        });
                                        commentInput.clear();
                                        commentFocusNode.unfocus();
                                      },
                                      icon: Icon(
                                        hasDraft
                                            ? Icons.arrow_upward_rounded
                                            : Icons.add_rounded,
                                        color: hasDraft
                                            ? _videoPurple
                                            : const Color(0xFF101116),
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (showEmojiPanel)
                                _CommentEmojiPanel(
                                  key: const Key('video-comment-emoji-panel'),
                                  onSelected: (emoji) {
                                    appendCommentText(emoji);
                                    setSheetState(() {});
                                  },
                                ),
                              if (showTools)
                                Column(
                                  key: const Key('video-comment-tools-panel'),
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 42,
                                        top: 4,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _CommentToolCard(
                                            key: const Key(
                                              'video-comment-mention-tile',
                                            ),
                                            actionKey: const Key(
                                              'video-comment-mention-button',
                                            ),
                                            label: '提及好友',
                                            icon: Icons.alternate_email_rounded,
                                            accent: _videoPurple,
                                            background: const Color(0xFFF2F0FF),
                                            onPressed: () => setSheetState(() {
                                              showMentionPanel =
                                                  !showMentionPanel;
                                              showEmojiPanel = false;
                                            }),
                                          ),
                                          const SizedBox(width: 8),
                                          _CommentToolCard(
                                            key: const Key(
                                              'video-comment-image-tile',
                                            ),
                                            actionKey: const Key(
                                              'video-comment-image-button',
                                            ),
                                            label: '添加图片',
                                            icon: Icons
                                                .add_photo_alternate_rounded,
                                            accent: _videoCoral,
                                            background: const Color(0xFFFFF1F3),
                                            onPressed: () async {
                                              final selected =
                                                  await showModalBottomSheet<
                                                    String
                                                  >(
                                                    context: context,
                                                    showDragHandle: true,
                                                    builder: (pickerContext) =>
                                                        _CommentImagePicker(
                                                          onSelected: (asset) =>
                                                              Navigator.pop(
                                                                pickerContext,
                                                                asset,
                                                              ),
                                                        ),
                                                  );
                                              if (selected != null) {
                                                setSheetState(() {
                                                  pendingImage = selected;
                                                  showEmojiPanel = false;
                                                  showMentionPanel = false;
                                                });
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (showMentionPanel)
                                      _CommentOptionPanel(
                                        key: const Key(
                                          'video-comment-mention-panel',
                                        ),
                                        children: [
                                          for (final user in const [
                                            'Kevin AI',
                                            'Luna Design',
                                            '阿杰',
                                            '小宇',
                                          ])
                                            ActionChip(
                                              key: Key('video-mention-$user'),
                                              avatar: ChatAvatar.person(
                                                name: user,
                                                radius: 10,
                                              ),
                                              label: Text(user),
                                              onPressed: () {
                                                appendCommentText('@$user ');
                                                setSheetState(
                                                  () =>
                                                      showMentionPanel = false,
                                                );
                                                commentFocusNode.requestFocus();
                                              },
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted) resumeAfterOverlay();
  }

  Future<void> openShare(_VideoFeedItem video) async {
    pauseForOverlay();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '转发到',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _ShareOption(
                    key: const Key('share-friend'),
                    icon: Icons.chat_bubble_rounded,
                    label: '好友',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      showMessage('已选择转发给好友');
                    },
                  ),
                  _ShareOption(
                    key: const Key('share-copy-link'),
                    icon: Icons.link_rounded,
                    label: '复制链接',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      showMessage('视频链接已复制');
                    },
                  ),
                  _ShareOption(
                    key: const Key('share-save'),
                    icon: Icons.download_rounded,
                    label: '保存视频',
                    onTap: () {
                      Navigator.pop(sheetContext);
                      showMessage('视频已保存');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (mounted) resumeAfterOverlay();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> openGroup(_VideoFeedItem video) async {
    final groupName = video.groupName;
    if (groupName == null) return;
    setState(() => joinedGroups.add(groupName));
    pauseForOverlay();
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GroupChatScreen(
          groupName: groupName,
          memberCount: video.groupMembers ?? '0',
          currentUser: widget.session.nickname,
          session: widget.session,
        ),
      ),
    );
    if (mounted) resumeAfterOverlay();
  }

  Future<void> openShortDrama(_VideoFeedItem video) async {
    final dramaId = video.shortDramaId;
    final drama = dramaId == null ? null : shortDramas[dramaId];
    if (drama == null || drama.episodes.isEmpty) return;
    await pauseForOverlayAndWait();
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 240),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: ShortDramaFeedScreen(
            session: widget.session,
            drama: drama,
            api: shortDramaApi,
          ),
        ),
      ),
    );
    if (mounted) resumeAfterOverlay();
  }

  Widget buildVideoLayer(int index, _VideoFeedItem video) {
    final controller = videoControllers[index];
    final firstFrameReady =
        controller != null && controller.value.isInitialized;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: Image.asset(
            video.poster,
            fit: BoxFit.cover,
            semanticLabel: '${video.author}发布的视频加载占位图',
          ),
        ),
        if (firstFrameReady)
          FittedBox(
            key: Key(
              index == currentIndex
                  ? 'video-player-${video.id}'
                  : 'video-first-frame-${video.id}',
            ),
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.size.width,
              height: controller.value.size.height,
              child: VideoPlayer(controller),
            ),
          ),
        if (index == currentIndex && loadingVideos.contains(index))
          const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                value: 0.72,
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          ),
        if (index == currentIndex && failedVideos.contains(index))
          Center(
            child: Container(
              key: const Key('retry-video'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 5),
                  Text('视频加载失败，点击画面重试', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget buildVideoProgress(
    _VideoFeedItem video,
    VideoPlayerController? controller,
  ) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: controller?.value.isInitialized == true
          ? VideoProgressIndicator(
              controller!,
              key: Key('video-progress-${video.id}'),
              allowScrubbing: true,
              padding: EdgeInsets.zero,
              colors: const VideoProgressColors(
                playedColor: _videoPurple,
                bufferedColor: Colors.white38,
                backgroundColor: Colors.white24,
              ),
            )
          : LinearProgressIndicator(
              key: Key('video-progress-${video.id}'),
              value: 0,
              minHeight: 2,
              color: _videoPurple,
              backgroundColor: Colors.white24,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomOverlayInset =
        _videoOverlayBottomInset + MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: handleScrollNotification,
            child: PageView.builder(
              key: const Key('vertical-video-feed'),
              controller: pageController,
              scrollDirection: Axis.vertical,
              pageSnapping: false,
              allowImplicitScrolling: true,
              scrollCacheExtent: const ScrollCacheExtent.viewport(1),
              physics: pagePhysics,
              itemCount: videoItems.length,
              onPageChanged: (index) {
                setState(() {
                  currentIndex = index;
                  paused = false;
                  showLikeBurst = false;
                });
                prepareAround(index);
                if (remoteFeedReady && index >= videoItems.length - 3) {
                  unawaited(loadMoreVideos());
                }
              },
              itemBuilder: (context, index) {
                final video = videoItems[index];
                final liked = likedVideos.contains(video.id);
                final followed = followedCreators.contains(video.author);
                final joined = joinedGroups.contains(video.groupName);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      key: Key('video-page-${video.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: togglePlayback,
                      onDoubleTap: () => toggleLike(video, showBurst: true),
                      child: IgnorePointer(
                        child: buildVideoLayer(index, video),
                      ),
                    ),
                    if (index == currentIndex)
                      buildVideoProgress(video, videoControllers[index]),
                    if (paused)
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 74,
                            height: 74,
                            decoration: BoxDecoration(
                              color: _videoInk.withValues(alpha: 0.72),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              key: Key('video-paused-indicator'),
                              size: 48,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    Center(
                      child: IgnorePointer(
                        child: AnimatedOpacity(
                          key: const Key('video-like-burst'),
                          opacity: showLikeBurst && index == currentIndex
                              ? 1
                              : 0,
                          duration: const Duration(milliseconds: 120),
                          child: const Icon(
                            Icons.favorite_rounded,
                            color: _videoCoral,
                            size: 105,
                            shadows: [
                              Shadow(color: Colors.black38, blurRadius: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 14,
                      right:
                          _videoActionRailWidth +
                          _videoActionRailRightInset +
                          _videoContentActionGap,
                      bottom: bottomOverlayInset,
                      child: _VideoDescription(
                        video: video,
                        joined: joined,
                        onJoin: () => openGroup(video),
                        onOpenDrama: () => openShortDrama(video),
                      ),
                    ),
                    Positioned(
                      right: _videoActionRailRightInset,
                      bottom: bottomOverlayInset,
                      child: _VideoActionRail(
                        video: video,
                        liked: liked,
                        followed: followed,
                        commentCount: comments[video.id]?.length ?? 15,
                        likeCount: video.likes + (liked ? 1 : 0),
                        formatCount: compactCount,
                        onFollow: () => setState(() {
                          if (!followedCreators.add(video.author)) {
                            followedCreators.remove(video.author);
                          }
                        }),
                        onLike: () => toggleLike(video),
                        onComment: () => openComments(video),
                        onShare: () => openShare(video),
                      ),
                    ),
                    if (index == currentIndex && remoteFeedReady)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: bottomOverlayInset + 8,
                        child: _VideoLoadMoreState(
                          loading: loadingMore,
                          failed: loadMoreFailed,
                          hasMore: remotePagination.hasMore,
                          onRetry: loadMoreVideos,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoLoadMoreState extends StatelessWidget {
  const _VideoLoadMoreState({
    required this.loading,
    required this.failed,
    required this.hasMore,
    required this.onRetry,
  });

  final bool loading;
  final bool failed;
  final bool hasMore;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: KeyedSubtree(
          key: Key('video-load-more-loading'),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('正在加载更多', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (failed) {
      return Center(
        child: InkWell(
          key: const Key('video-load-more-retry'),
          onTap: onRetry,
          borderRadius: BorderRadius.circular(18),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.all(Radius.circular(18)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text('加载失败，点击重试', style: TextStyle(color: Colors.white)),
            ),
          ),
        ),
      );
    }
    if (!hasMore) {
      return const Center(
        child: KeyedSubtree(
          key: Key('video-load-more-end'),
          child: Text(
            '没有更多视频',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _VideoCommentTile extends StatelessWidget {
  const _VideoCommentTile({
    super.key,
    required this.comment,
    required this.expanded,
    required this.onToggleReplies,
    required this.onReply,
  });

  final _VideoComment comment;
  final bool expanded;
  final VoidCallback onToggleReplies;
  final ValueChanged<String> onReply;

  @override
  Widget build(BuildContext context) {
    final replies = comment.replies;
    final visibleReplies = expanded ? replies : replies.take(1).toList();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ChatAvatar.person(
          key: Key('video-comment-avatar-${comment.id}'),
          name: comment.author,
          radius: 19,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      comment.author,
                      style: const TextStyle(
                        color: Color(0xFF767884),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const Column(
                    children: [
                      Icon(
                        Icons.favorite_border_rounded,
                        size: 18,
                        color: Color(0xFF8D8F99),
                      ),
                      Text(
                        '赞',
                        style: TextStyle(
                          color: Color(0xFF9A9CA5),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (comment.content.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(
                    color: Color(0xFF17181C),
                    fontSize: 15,
                    height: 1.38,
                  ),
                ),
              ],
              if (comment.imageAsset != null) ...[
                const SizedBox(height: 8),
                _CommentImage(
                  key: Key('video-comment-image-${comment.id}'),
                  asset: comment.imageAsset!,
                ),
              ],
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(
                    comment.time,
                    key: Key('video-comment-time-${comment.id}'),
                    style: const TextStyle(
                      color: Color(0xFF9A9CA5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 14),
                  GestureDetector(
                    key: Key('reply-to-${comment.id}'),
                    onTap: () => onReply(comment.author),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        '回复',
                        style: TextStyle(
                          color: Color(0xFF666873),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (visibleReplies.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final reply in visibleReplies) ...[
                  _VideoCommentReplyTile(
                    key: Key('video-comment-reply-${reply.id}'),
                    reply: reply,
                    onReply: () => onReply(reply.author),
                  ),
                  if (reply != visibleReplies.last) const SizedBox(height: 10),
                ],
              ],
              if (replies.length > 1) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  key: Key('expand-replies-${comment.id}'),
                  onTap: onToggleReplies,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 24,
                          height: 1,
                          color: const Color(0xFFB6B7BD),
                        ),
                        const SizedBox(width: 7),
                        Text(
                          expanded ? '收起回复' : '展开剩余 ${replies.length - 1} 条回复',
                          style: const TextStyle(
                            color: Color(0xFF696B75),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 17,
                          color: const Color(0xFF696B75),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoCommentReplyTile extends StatelessWidget {
  const _VideoCommentReplyTile({
    super.key,
    required this.reply,
    required this.onReply,
  });

  final _VideoCommentReply reply;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ChatAvatar.person(
        key: Key('video-comment-reply-avatar-${reply.id}'),
        name: reply.author,
        radius: 13,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reply.author,
              style: const TextStyle(
                color: Color(0xFF767884),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  if (reply.replyTo != null)
                    TextSpan(
                      text: '回复 @${reply.replyTo}  ',
                      style: const TextStyle(
                        color: Color(0xFF536A9E),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  TextSpan(text: reply.content),
                ],
              ),
              style: const TextStyle(
                color: Color(0xFF24252A),
                fontSize: 13,
                height: 1.35,
              ),
            ),
            if (reply.imageAsset != null) ...[
              const SizedBox(height: 7),
              _CommentImage(asset: reply.imageAsset!, compact: true),
            ],
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  reply.time,
                  style: const TextStyle(
                    color: Color(0xFF9A9CA5),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onReply,
                  child: const Text(
                    '回复',
                    style: TextStyle(
                      color: Color(0xFF666873),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

class _CommentImage extends StatelessWidget {
  const _CommentImage({super.key, required this.asset, this.compact = false});

  final String asset;
  final bool compact;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.asset(
      asset,
      width: compact ? 104 : 148,
      height: compact ? 78 : 108,
      fit: BoxFit.cover,
    ),
  );
}

class _CommentEmojiPanel extends StatelessWidget {
  const _CommentEmojiPanel({super.key, required this.onSelected});

  final ValueChanged<String> onSelected;

  static const emojis = ['😀', '😍', '👍', '🔥', '🎉', '😂', '💡', '❤️'];

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 4),
    padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
    color: Colors.white,
    child: Row(
      children: [
        for (final emoji in emojis)
          Expanded(
            child: IconButton(
              key: Key('video-comment-emoji-$emoji'),
              tooltip: emoji,
              onPressed: () => onSelected(emoji),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              icon: CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xFF101116),
                child: Text(emoji, style: const TextStyle(fontSize: 22)),
              ),
            ),
          ),
      ],
    ),
  );
}

class _CommentOptionPanel extends StatelessWidget {
  const _CommentOptionPanel({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF6F6F8),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Wrap(spacing: 4, runSpacing: 4, children: children),
  );
}

class _CommentToolCard extends StatelessWidget {
  const _CommentToolCard({
    super.key,
    required this.actionKey,
    required this.label,
    required this.icon,
    required this.accent,
    required this.background,
    required this.onPressed,
  });

  final Key actionKey;
  final String label;
  final IconData icon;
  final Color accent;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: Material(
      color: background,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: actionKey,
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: Icon(icon, size: 19, color: accent),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF292A38),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CommentInputAction extends StatelessWidget {
  const _CommentInputAction({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.backgroundColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 40, height: 40),
    visualDensity: VisualDensity.compact,
    style: backgroundColor == null
        ? null
        : IconButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: iconColor,
          ),
    icon: Icon(icon, size: 20, color: iconColor ?? const Color(0xFF555760)),
  );
}

class _CommentImagePicker extends StatelessWidget {
  const _CommentImagePicker({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const images = [
    'assets/images/community-design-collaboration.png',
    'assets/images/ai-video-workflow.png',
    'assets/images/community-design-match.jpg',
  ];

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '选择评论图片',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (var index = 0; index < images.length; index++) ...[
                Expanded(
                  child: InkWell(
                    key: Key('video-comment-image-option-$index'),
                    onTap: () => onSelected(images[index]),
                    borderRadius: BorderRadius.circular(10),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.asset(images[index], fit: BoxFit.cover),
                      ),
                    ),
                  ),
                ),
                if (index != images.length - 1) const SizedBox(width: 9),
              ],
            ],
          ),
        ],
      ),
    ),
  );
}

class _VideoDescription extends StatelessWidget {
  const _VideoDescription({
    required this.video,
    required this.joined,
    required this.onJoin,
    required this.onOpenDrama,
  });

  final _VideoFeedItem video;
  final bool joined;
  final VoidCallback onJoin;
  final VoidCallback onOpenDrama;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('video-description-overlay'),
    padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(20)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (video.isShortDrama) ...[
          GestureDetector(
            key: Key('short-drama-entry-${video.id}'),
            onTap: onOpenDrama,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF95C8F4).withValues(alpha: 0.18),
                border: Border.all(
                  color: const Color(0xFF95C8F4).withValues(alpha: 0.52),
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(11, 9, 9, 9),
                child: Row(
                  children: [
                    const Icon(
                      Icons.local_movies_rounded,
                      key: Key('short-drama-entry-icon'),
                      color: Color(0xFF95C8F4),
                      size: 19,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            video.shortDramaName ?? '短剧',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '共 ${video.shortDramaEpisodeCount ?? 0} 集 · 第 1 集',
                            style: const TextStyle(
                              color: Color(0xFFD9ECFF),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '进入短剧  ›',
                      style: TextStyle(
                        color: Color(0xFF95C8F4),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
        ],
        Row(
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: _videoPurple,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '@${video.author}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Color(0xCC000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (shortDramaVideoDescription(
              isShortDrama: video.isShortDrama,
              caption: video.caption,
            ) !=
            null) ...[
          const SizedBox(height: 8),
          Text(
            shortDramaVideoDescription(
              isShortDrama: video.isShortDrama,
              caption: video.caption,
            )!,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFF4F3FA),
              fontSize: 14,
              height: 1.42,
              shadows: [
                Shadow(
                  color: Color(0xCC000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
        if (video.groupName != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 38,
            child: DecoratedBox(
              key: Key('join-video-group-shell-${video.id}'),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF7667F4), Color(0xFF5146C8)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _videoPurple.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: OutlinedButton.icon(
                key: Key('join-video-group-${video.id}'),
                onPressed: onJoin,
                icon: const Icon(Icons.groups_2_rounded, size: 17),
                label: Text(
                  joined ? '已加入 · 进入群聊' : '加入 ${video.groupName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.transparent,
                  overlayColor: Colors.white.withValues(alpha: 0.16),
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class _VideoActionRail extends StatelessWidget {
  const _VideoActionRail({
    required this.video,
    required this.liked,
    required this.followed,
    required this.commentCount,
    required this.likeCount,
    required this.formatCount,
    required this.onFollow,
    required this.onLike,
    required this.onComment,
    required this.onShare,
  });

  final _VideoFeedItem video;
  final bool liked;
  final bool followed;
  final int commentCount;
  final int likeCount;
  final String Function(int value) formatCount;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('video-action-rail'),
    width: 66,
    padding: const EdgeInsets.fromLTRB(5, 8, 5, 7),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(33)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 54,
          height: 59,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: ChatAvatar.person(name: video.author, radius: 22),
              ),
              Positioned(
                bottom: 0,
                child: Semantics(
                  button: true,
                  label: followed
                      ? '已关注 ${video.author}'
                      : '关注 ${video.author}',
                  child: GestureDetector(
                    key: Key('video-follow-${video.id}'),
                    onTap: onFollow,
                    child: Container(
                      width: 23,
                      height: 23,
                      decoration: BoxDecoration(
                        color: followed ? Colors.white : _videoPurple,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Icon(
                        followed ? Icons.check_rounded : Icons.add_rounded,
                        color: followed ? _videoPurple : Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _VideoAction(
          key: Key('video-like-${video.id}'),
          actionLabel: '点赞',
          icon: Icons.favorite_rounded,
          active: liked,
          color: liked ? _videoCoral : Colors.white,
          label: formatCount(likeCount),
          onTap: onLike,
        ),
        const SizedBox(height: 8),
        _VideoAction(
          key: Key('video-comment-${video.id}'),
          actionLabel: '评论',
          icon: Icons.chat_bubble_rounded,
          label: '$commentCount',
          onTap: onComment,
        ),
        const SizedBox(height: 8),
        _VideoAction(
          key: Key('video-share-${video.id}'),
          actionLabel: '分享转发',
          icon: Icons.reply_rounded,
          label: formatCount(video.shares),
          onTap: onShare,
        ),
      ],
    ),
  );
}

class _VideoAction extends StatelessWidget {
  const _VideoAction({
    super.key,
    required this.actionLabel,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white,
    this.active = false,
  });

  final String actionLabel;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '$actionLabel $label',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      splashColor: Colors.white24,
      highlightColor: Colors.white10,
      child: SizedBox(
        width: 54,
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: active ? 1.12 : 1,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: Icon(
                icon,
                color: color,
                size: 29,
                shadows: const [Shadow(color: Colors.black38, blurRadius: 3)],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1,
                shadows: [
                  Shadow(
                    color: Color(0xCC000000),
                    blurRadius: 5,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ShareOption extends StatelessWidget {
  const _ShareOption({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFF0EEFF),
            child: Icon(icon, color: const Color(0xFF6256E8)),
          ),
          const SizedBox(height: 7),
          Text(label),
        ],
      ),
    ),
  );
}
