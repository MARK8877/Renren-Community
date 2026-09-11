import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../auth/auth_session.dart';
import '../community/community_post.dart';
import 'community_publish_screen.dart';
import 'group_chat_screen.dart';
import 'messages_screen.dart';
import 'profile_screen.dart';
import 'video_feed_screen.dart';
import '../widgets/chat_avatar.dart';

class _SamplePostData {
  const _SamplePostData({
    required this.id,
    required this.author,
    required this.role,
    required this.time,
    required this.content,
    required this.tags,
    required this.likes,
    required this.comments,
    this.images = const [],
    this.groupId,
    this.groupName,
    this.groupMemberCount,
  });

  final String id;
  final String author;
  final String role;
  final String time;
  final String content;
  final List<String> tags;
  final String likes;
  final String comments;
  final List<String> images;
  final String? groupId;
  final String? groupName;
  final String? groupMemberCount;
}

const _samplePosts = [
  _SamplePostData(
    id: 'design-review',
    author: 'Ada Product',
    role: '产品经理',
    time: '12 分钟前',
    content: '刚结束一轮社区首页评审。比起继续增加入口，让用户更快找到愿意交流的人，可能才是下一步最值得验证的方向。',
    tags: ['#产品思考', '#社区设计'],
    likes: '236',
    comments: '41',
  ),
  _SamplePostData(
    id: 'photo-walk',
    author: '阿北摄影',
    role: '城市摄影师',
    time: '18 分钟前',
    content: '今天的城市漫步结束了。大家没有赶着出片，而是一起聊了很久构图和光线，这种松弛的交流特别难得。',
    tags: ['#城市漫步', '#摄影交流'],
    likes: '189',
    comments: '27',
  ),
  _SamplePostData(
    id: 'ai-workflow',
    author: '小宇 AI',
    role: 'AI 创作者',
    time: '26 分钟前',
    content: '把今天测试的 AI 视频工作流整理成了一张图。先确定分镜，再生成关键帧，最后补运动，比直接反复抽卡稳定很多。',
    tags: ['#AI视频', '#创作流程'],
    likes: '642',
    comments: '88',
    images: ['assets/images/ai-video-workflow.png'],
  ),
  _SamplePostData(
    id: 'new-member',
    author: 'Mia Growth',
    role: '社区运营',
    time: '34 分钟前',
    content: '新成员欢迎语不要只写群规。先告诉他这里有什么人、正在讨论什么、第一件可以参与的小事，开口率会明显提升。',
    tags: ['#社区运营', '#新用户'],
    likes: '318',
    comments: '53',
  ),
  _SamplePostData(
    id: 'co-design',
    author: '林木 Design',
    role: '交互设计师',
    time: '42 分钟前',
    content: '今天邀请五位社区成员一起改原型。很多我们认为“理所当然”的操作，他们第一次用时完全找不到。真实反馈永远比猜测更有价值。',
    tags: ['#共创工作坊', '#用户体验'],
    likes: '476',
    comments: '69',
    images: ['assets/images/community-design-collaboration.png'],
  ),
  _SamplePostData(
    id: 'poster-test',
    author: 'Nora Studio',
    role: '视觉设计师',
    time: '55 分钟前',
    content: '同一个活动做了两套视觉方向，强信息型和赛事氛围型各有优势。准备交给社区成员投票决定最终版本。',
    tags: ['#视觉设计', '#方案投票'],
    likes: '527',
    comments: '104',
    images: [
      'assets/images/community-design-lucky-king.jpg',
      'assets/images/community-design-match.jpg',
    ],
  ),
  _SamplePostData(
    id: 'flutter-notes',
    author: '阿杰 Dev',
    role: 'Flutter 开发者',
    time: '1 小时前',
    content: '今天把聊天输入框的多行、自适应高度和键盘焦点统一了。组件越早统一，后面新增私聊和群聊功能越省心。',
    tags: ['#Flutter', '#开发记录'],
    likes: '205',
    comments: '36',
  ),
  _SamplePostData(
    id: 'group-rules',
    author: '七喜',
    role: '社区主理人',
    time: '1 小时前',
    content: '好的群规则不是越长越好，而是让每个人都知道什么可以做、遇到问题找谁、破坏交流氛围会有什么结果。',
    tags: ['#社群管理', '#群规则'],
    likes: '152',
    comments: '24',
  ),
  _SamplePostData(
    id: 'football-night',
    author: '足球星球',
    role: '体育社区',
    time: '2 小时前',
    content: '今晚的观赛讨论帖已经准备好。赛前聊阵容，比赛中只讨论场上内容，赛后一起评选本场最佳。',
    tags: ['#足球', '#一起看球'],
    likes: '891',
    comments: '216',
    images: ['assets/images/community-design-match.jpg'],
  ),
  _SamplePostData(
    id: 'event-visual',
    author: '活动实验室',
    role: '活动策划',
    time: '2 小时前',
    content: '活动海报第一版完成。信息层级、奖励数字和行动按钮都做了强化，欢迎大家从“是否一眼看懂”的角度给建议。',
    tags: ['#活动策划', '#海报设计'],
    likes: '347',
    comments: '78',
    images: ['assets/images/community-design-lucky-king.jpg'],
  ),
  _SamplePostData(
    id: 'creator-rhythm',
    author: 'Kevin AI',
    role: '视频创作者',
    time: '3 小时前',
    content: '连续更新不等于每天硬撑。我的节奏是两天收集问题、一天集中制作、一天回复评论，反而比日更稳定。',
    tags: ['#创作者成长', '#内容运营'],
    likes: '734',
    comments: '95',
  ),
  _SamplePostData(
    id: 'music-room',
    author: 'Jay Music',
    role: '独立音乐人',
    time: '3 小时前',
    content: '今晚九点开放线上听歌房。每个人带一首最近循环的歌，不限风格，讲讲为什么它在这个阶段打动了你。',
    tags: ['#音乐分享', '#线上活动'],
    likes: '268',
    comments: '61',
  ),
  _SamplePostData(
    id: 'story-workshop',
    author: '绘本森林',
    role: '插画创作者',
    time: '4 小时前',
    content: '周末共创工作坊记录：先由孩子讲故事，成年人只负责提问和整理，最后再一起把情节变成画面。',
    tags: ['#插画', '#共创'],
    likes: '423',
    comments: '57',
    images: ['assets/images/community-design-collaboration.png'],
  ),
  _SamplePostData(
    id: 'tool-comparison',
    author: '数码研究所',
    role: '效率博主',
    time: '5 小时前',
    content: '整理了三种视频工作流的对比。工具不是越多越好，能让素材、版本和反馈顺畅流动的组合，才是真正适合团队的组合。',
    tags: ['#效率工具', '#工作流'],
    likes: '582',
    comments: '83',
    images: [
      'assets/images/ai-video-workflow.png',
      'assets/images/community-design-collaboration.png',
      'assets/images/community-design-match.jpg',
    ],
  ),
  _SamplePostData(
    id: 'weekend-friends',
    author: '周末搭子',
    role: '兴趣小组',
    time: '6 小时前',
    content: '这周六想组织一次不赶路的公园野餐，人数控制在八人。每个人准备一种零食和一个最近想讨论的话题就好。',
    tags: ['#同城活动', '#认识新朋友'],
    likes: '194',
    comments: '49',
  ),
];

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const initialPageSize = 6;
  static const loadMorePageSize = 5;

  String topTab = '推荐';
  String category = '精选';
  int bottomIndex = 0;
  bool videoPlaying = false;
  bool loadingMore = false;
  int visibleSampleCount = initialPageSize;
  final ScrollController feedController = ScrollController();
  final Set<String> followedAuthors = {};
  final Set<String> joinedCommunities = {};
  final Set<String> likedPosts = {};
  final Set<String> bookmarkedPosts = {};
  final CommunityPostStore communityPostStore = CommunityPostStore();
  final List<CommunityPost> publishedPosts = [];
  late final List<_SamplePostData> samplePosts;

  @override
  void initState() {
    super.initState();
    samplePosts = List<_SamplePostData>.of(_samplePosts)..shuffle(Random());
    feedController.addListener(handleFeedScroll);
    unawaited(loadPublishedPosts());
  }

  @override
  void dispose() {
    feedController
      ..removeListener(handleFeedScroll)
      ..dispose();
    super.dispose();
  }

  int get currentSampleTotal {
    if (topTab != '关注') return samplePosts.length;
    return samplePosts
        .where((post) => followedAuthors.contains(post.author))
        .length;
  }

  bool get canLoadMore => visibleSampleCount < currentSampleTotal;

  void handleFeedScroll() {
    if (!feedController.hasClients || bottomIndex != 0) return;
    if (feedController.position.extentAfter < 240) unawaited(loadMore());
  }

  Future<void> loadMore() async {
    if (loadingMore || !canLoadMore) return;
    final requestedTab = topTab;
    setState(() => loadingMore = true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || requestedTab != topTab) return;
    setState(() {
      visibleSampleCount = min(
        visibleSampleCount + loadMorePageSize,
        currentSampleTotal,
      );
      loadingMore = false;
    });
  }

  Future<void> refreshFeed() async {
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() {
      samplePosts.shuffle(Random());
      visibleSampleCount = initialPageSize;
      loadingMore = false;
    });
    showMessage('已刷新最新内容');
  }

  Future<void> loadPublishedPosts() async {
    final posts = await communityPostStore.load(widget.session.nickname);
    if (!mounted) return;
    setState(() {
      publishedPosts
        ..clear()
        ..addAll(posts);
    });
  }

  Future<void> openPublish() async {
    final post = await Navigator.push<CommunityPost>(
      context,
      MaterialPageRoute<CommunityPost>(
        builder: (_) => CommunityPublishScreen(session: widget.session),
      ),
    );
    if (post == null || !mounted) return;
    setState(() {
      bottomIndex = 0;
      publishedPosts.insert(0, post);
    });
    try {
      await communityPostStore.save(widget.session.nickname, publishedPosts);
      if (mounted) showMessage('动态发布成功');
    } catch (_) {
      if (mounted) showMessage('动态已发布，本地保存失败');
    }
  }

  String publishedTime(DateTime createdAt) {
    final difference = DateTime.now().difference(createdAt);
    if (difference.inMinutes < 1) return '刚刚';
    if (difference.inHours < 1) return '${difference.inMinutes} 分钟前';
    if (difference.inDays < 1) return '${difference.inHours} 小时前';
    return '${createdAt.month}/${createdAt.day}';
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void toggle(Set<String> values, String value) {
    setState(
      () => values.contains(value) ? values.remove(value) : values.add(value),
    );
  }

  Future<void> openGroupChat(
    String groupName,
    String memberCount, {
    String? conversationId,
  }) async {
    final membershipKey = conversationId ?? groupName;
    setState(() => joinedCommunities.add(membershipKey));
    final exited = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => GroupChatScreen(
          groupName: groupName,
          memberCount: memberCount,
          currentUser: widget.session.nickname,
          session: widget.session,
          conversationId: conversationId,
        ),
      ),
    );
    if (exited == true && mounted) {
      setState(() => joinedCommunities.remove(membershipKey));
      showMessage('已退出$groupName');
    }
  }

  void openVideoFeed() => setState(() => bottomIndex = 1);

  int metricValue(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.endsWith('k')) {
      return ((double.tryParse(
                    normalized.substring(0, normalized.length - 1),
                  ) ??
                  0) *
              1000)
          .round();
    }
    return int.tryParse(normalized.replaceAll(',', '')) ?? 0;
  }

  int postHeat(_SamplePostData post) =>
      metricValue(post.likes) + metricValue(post.comments);

  Widget samplePostCard(_SamplePostData post) {
    return _SamplePostCard(
      key: Key('sample-post-${post.id}'),
      post: post,
      followed: followedAuthors.contains(post.author),
      liked: likedPosts.contains(post.id),
      bookmarked: bookmarkedPosts.contains(post.id),
      onFollow: () => toggle(followedAuthors, post.author),
      onLike: () => toggle(likedPosts, post.id),
      onBookmark: () => toggle(bookmarkedPosts, post.id),
      onComment: () => showMessage('评论入口已打开'),
      onShare: () => showMessage('分享入口已打开'),
    );
  }

  Widget publishedPostCard(CommunityPost post) {
    return _SamplePostCard(
      key: Key('published-post-${post.id}'),
      post: _SamplePostData(
        id: 'published-${post.id}',
        author: post.author,
        role: '社区成员',
        time: publishedTime(post.createdAt),
        content: post.content,
        tags: post.tags,
        likes: '0',
        comments: '0',
        groupId: post.groupId,
        groupName: post.groupName,
        groupMemberCount: post.groupMemberCount,
      ),
      followed: true,
      liked: likedPosts.contains('published-${post.id}'),
      bookmarked: bookmarkedPosts.contains('published-${post.id}'),
      joined: post.groupId != null && joinedCommunities.contains(post.groupId),
      onFollow: () {},
      onLike: () => toggle(likedPosts, 'published-${post.id}'),
      onBookmark: () => toggle(bookmarkedPosts, 'published-${post.id}'),
      onComment: () => showMessage('评论入口已打开'),
      onShare: () => showMessage('分享入口已打开'),
      onJoin: post.groupId == null || post.groupName == null
          ? null
          : () => openGroupChat(
              post.groupName!,
              post.groupMemberCount ?? '1',
              conversationId: post.groupId,
            ),
    );
  }

  Widget videoPostCard() {
    return _VideoPostCard(
      playing: videoPlaying,
      followed: followedAuthors.contains('Kevin AI'),
      joined: joinedCommunities.contains('AI 视频创作者交流群'),
      liked: likedPosts.contains('video'),
      bookmarked: bookmarkedPosts.contains('video'),
      onPlay: () => setState(() => videoPlaying = !videoPlaying),
      onFollow: () => toggle(followedAuthors, 'Kevin AI'),
      onJoin: () => openGroupChat('AI 视频创作者交流群', '2,856'),
      onLike: () => toggle(likedPosts, 'video'),
      onBookmark: () => toggle(bookmarkedPosts, 'video'),
      onComment: () => showMessage('评论入口已打开'),
      onShare: () => showMessage('分享入口已打开'),
    );
  }

  Widget articlePostCard() {
    return _ArticlePostCard(
      followed: followedAuthors.contains('Luna Design'),
      joined: joinedCommunities.contains('产品设计交流社区'),
      liked: likedPosts.contains('article'),
      bookmarked: bookmarkedPosts.contains('article'),
      onFollow: () => toggle(followedAuthors, 'Luna Design'),
      onJoin: () => openGroupChat('产品设计交流社区', '18,420'),
      onLike: () => toggle(likedPosts, 'article'),
      onBookmark: () => toggle(bookmarkedPosts, 'article'),
      onComment: () => showMessage('评论入口已打开'),
      onShare: () => showMessage('分享入口已打开'),
    );
  }

  List<Widget> channelFeed() {
    final children = <Widget>[];
    void add(Widget child) {
      if (children.isNotEmpty) children.add(const SizedBox(height: 14));
      children.add(child);
    }

    if (topTab == '关注') {
      final followedPosts = samplePosts
          .where((post) => followedAuthors.contains(post.author))
          .take(visibleSampleCount)
          .toList();
      final followsKevin = followedAuthors.contains('Kevin AI');
      final followsLuna = followedAuthors.contains('Luna Design');

      if (!followsKevin && !followsLuna && followedPosts.isEmpty) {
        add(
          _FollowingEmptyState(
            onExplore: () {
              setState(() {
                topTab = '推荐';
                visibleSampleCount = initialPageSize;
                loadingMore = false;
              });
              showMessage('已切换到推荐内容');
            },
          ),
        );
        return children;
      }
      if (followsKevin) add(videoPostCard());
      if (followsLuna) add(articlePostCard());
      for (final post in followedPosts) {
        add(samplePostCard(post));
      }
      add(
        _FeedLoadStatus(
          loading: loadingMore,
          loaded: followedPosts.length,
          total: currentSampleTotal,
          completeText: '以上是你关注的创作者动态',
        ),
      );
      return children;
    }

    if (topTab == '热门') {
      final hotPosts = List<_SamplePostData>.of(samplePosts)
        ..sort((a, b) => postHeat(b).compareTo(postHeat(a)));
      final visibleHotPosts = hotPosts.take(visibleSampleCount).toList();
      const articleHeat = 660;
      add(const _ChannelHint(text: '按点赞与评论互动热度排序'));
      add(videoPostCard());
      for (final post in visibleHotPosts.where(
        (post) => postHeat(post) > articleHeat,
      )) {
        add(samplePostCard(post));
      }
      add(articlePostCard());
      for (final post in visibleHotPosts.where(
        (post) => postHeat(post) <= articleHeat,
      )) {
        add(samplePostCard(post));
      }
      for (final post in publishedPosts) {
        add(publishedPostCard(post));
      }
      add(
        _FeedLoadStatus(
          loading: loadingMore,
          loaded: visibleHotPosts.length,
          total: hotPosts.length,
          completeText: '已按热度展示全部内容',
        ),
      );
      return children;
    }

    add(
      _WelcomeCard(
        onVideo: openVideoFeed,
        onGroup: () => openGroupChat('产品设计交流社区', '18,420'),
      ),
    );
    add(
      const Text(
        '推荐动态',
        key: Key('recommended-feed-title'),
        style: TextStyle(
          color: Color(0xFF17213A),
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
    );
    add(videoPostCard());
    add(articlePostCard());
    for (final post in publishedPosts) {
      add(publishedPostCard(post));
    }
    final visiblePosts = samplePosts.take(visibleSampleCount).toList();
    for (final post in visiblePosts) {
      add(samplePostCard(post));
    }
    add(
      _FeedLoadStatus(
        key: const Key('sample-post-end'),
        loading: loadingMore,
        loaded: visiblePosts.length,
        total: samplePosts.length,
        completeText: '已加载全部 15 条社区动态',
      ),
    );
    return children;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: const Color(0xFFF7F7FA),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: bottomIndex == 1
            ? VideoFeedScreen(
                key: const ValueKey('video-tab'),
                session: widget.session,
                showBackButton: false,
              )
            : bottomIndex == 2
            ? MessagesScreen(
                key: const ValueKey('messages-tab'),
                session: widget.session,
                showBottomNavigation: false,
              )
            : bottomIndex == 3
            ? ProfileScreen(
                key: const ValueKey('profile-tab'),
                session: widget.session,
              )
            : Stack(
                key: const ValueKey('home-tab'),
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        key: const Key('home-background-gradient'),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            stops: [0, 0.32, 0.72, 1],
                            colors: [
                              Color(0xFFE0DCFF),
                              Color(0xFFF3EEFF),
                              Color(0xFFFFF3EA),
                              Color(0xFFF7F7FA),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: RefreshIndicator(
                      key: const Key('home-refresh-indicator'),
                      onRefresh: refreshFeed,
                      child: CustomScrollView(
                        key: const PageStorageKey('home-feed-scroll'),
                        controller: feedController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        scrollCacheExtent: const ScrollCacheExtent.viewport(
                          1.25,
                        ),
                        slivers: [
                          SliverToBoxAdapter(
                            child: _Header(
                              selectedTab: topTab,
                              onTabSelected: (value) {
                                setState(() {
                                  topTab = value;
                                  visibleSampleCount = initialPageSize;
                                  loadingMore = false;
                                });
                                showMessage('已切换到$value内容');
                              },
                              onSearch: () => showMessage('搜索入口已打开'),
                              onNotifications: () => showMessage('暂无新通知'),
                            ),
                          ),
                          if (topTab != '关注')
                            SliverToBoxAdapter(
                              child: _CategoryBar(
                                selected: category,
                                onSelected: (value) {
                                  setState(() => category = value);
                                  showMessage('正在查看$value分类');
                                },
                              ),
                            ),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                            sliver: SliverList.list(
                              key: const Key('home-single-column-feed'),
                              children: channelFeed(),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: _BottomNavigation(
        selectedIndex: bottomIndex,
        onSelected: (index, label) {
          setState(() => bottomIndex = index);
          if (index == 0) showMessage('已回到首页');
        },
        onPublish: openPublish,
      ),
    );
  }
}

class _ChannelHint extends StatelessWidget {
  const _ChannelHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('hot-channel-hint'),
      children: [
        const Icon(
          Icons.local_fire_department_rounded,
          size: 18,
          color: Color(0xFFFF6B45),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            color: Color(0xFF6D6F78),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FollowingEmptyState extends StatelessWidget {
  const _FollowingEmptyState({required this.onExplore});

  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('following-empty-state'),
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_add_alt_1_rounded,
            size: 48,
            color: Color(0xFF7066FF),
          ),
          const SizedBox(height: 14),
          const Text(
            '还没有关注任何创作者',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            '关注感兴趣的创作者后，他们的最新动态会显示在这里。',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF858791),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            key: const Key('following-explore'),
            onPressed: onExplore,
            child: const Text('去推荐看看'),
          ),
        ],
      ),
    );
  }
}

class _FeedLoadStatus extends StatelessWidget {
  const _FeedLoadStatus({
    super.key,
    required this.loading,
    required this.loaded,
    required this.total,
    required this.completeText,
  });

  final bool loading;
  final int loaded;
  final int total;
  final String completeText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: loading
            ? const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    key: Key('home-load-more'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '正在加载更多动态',
                    style: TextStyle(color: Color(0xFF9698A2), fontSize: 12),
                  ),
                ],
              )
            : Text(
                loaded < total ? '上拉加载更多 · 已加载 $loaded/$total' : completeText,
                style: const TextStyle(color: Color(0xFF9698A2), fontSize: 12),
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.selectedTab,
    required this.onTabSelected,
    required this.onSearch,
    required this.onNotifications,
  });
  final String selectedTab;
  final ValueChanged<String> onTabSelected;
  final VoidCallback onSearch;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('editorial-home-header'),
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 44,
              child: Row(
                children: [
                  const SizedBox(width: 44),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _TopTab(
                            label: '关注',
                            selected: selectedTab == '关注',
                            onTap: () => onTabSelected('关注'),
                          ),
                        ),
                        Expanded(
                          child: _TopTab(
                            label: '推荐',
                            selected: selectedTab == '推荐',
                            onTap: () => onTabSelected('推荐'),
                          ),
                        ),
                        Expanded(
                          child: _TopTab(
                            label: '热门',
                            selected: selectedTab == '热门',
                            onTap: () => onTabSelected('热门'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 44,
                    child: _RoundIcon(
                      icon: CupertinoIcons.bell,
                      tooltip: '通知',
                      showBadge: true,
                      onTap: onNotifications,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(22),
              child: InkWell(
                key: const Key('home-search-bar'),
                borderRadius: BorderRadius.circular(22),
                onTap: onSearch,
                child: const SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      SizedBox(width: 15),
                      Icon(
                        CupertinoIcons.search,
                        color: Color(0xFF777B8A),
                        size: 20,
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '搜索创作者、社区和话题',
                          style: TextStyle(
                            color: Color(0xFF777B8A),
                            fontSize: 14,
                          ),
                        ),
                      ),
                      Icon(
                        CupertinoIcons.mic,
                        color: Color(0xFF777B8A),
                        size: 20,
                      ),
                      SizedBox(width: 15),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.showBadge = false,
  });
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            key: Key('header-$tooltip'),
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: SizedBox(
              width: 44,
              height: 44,
              child: Icon(icon, color: const Color(0xFF384052), size: 21),
            ),
          ),
        ),
        if (showBadge)
          const Positioned(
            right: 1,
            top: 1,
            child: CircleAvatar(radius: 4, backgroundColor: Color(0xFFFF4D67)),
          ),
      ],
    );
  }
}

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('top-tab-$label'),
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 17,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? const Color(0xFF17213A)
                    : const Color(0xFF858897),
              ),
            ),
            const SizedBox(height: 5),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selected ? 24 : 0,
              height: 2,
              decoration: const BoxDecoration(
                color: Color(0xFF6957E8),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const labels = ['AI创作', '设计共创', '摄影社区', '科技', '同城活动', '兴趣群聊', '创作课程', '更多'];
    const values = ['AI', '设计', '摄影', '科技', '同城', '群聊', '课程', '更多'];
    const icons = [
      Icons.auto_awesome_rounded,
      Icons.draw_rounded,
      Icons.camera_alt_outlined,
      Icons.memory_rounded,
      Icons.location_on_outlined,
      Icons.forum_outlined,
      Icons.school_outlined,
      Icons.grid_view_rounded,
    ];
    const colors = [
      Color(0xFF6957E8),
      Color(0xFFFF785F),
      Color(0xFF3B8EDB),
      Color(0xFF6255C9),
      Color(0xFFEC6E91),
      Color(0xFF3B9E8B),
      Color(0xFFF2A33A),
      Color(0xFF73788A),
    ];
    return Container(
      key: const Key('editorial-category-rail'),
      height: 164,
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: GridView.builder(
        key: const Key('home-quick-entry-grid'),
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 72,
        ),
        itemBuilder: (context, index) {
          final isSelected = values[index] == selected;
          return InkWell(
            key: Key('category-${values[index]}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelected(values[index]),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? colors[index]
                        : colors[index].withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    icons[index],
                    color: isSelected ? Colors.white : colors[index],
                    size: 22,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  labels[index],
                  maxLines: 1,
                  style: TextStyle(
                    color: isSelected ? colors[index] : const Color(0xFF333746),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
        itemCount: labels.length,
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.onVideo, required this.onGroup});

  final VoidCallback onVideo;
  final VoidCallback onGroup;

  @override
  Widget build(BuildContext context) {
    Widget entry({
      required Key key,
      required String label,
      required List<Color> colors,
      required VoidCallback onTap,
      required Widget child,
    }) {
      return Expanded(
        child: Semantics(
          button: true,
          label: label,
          child: Material(
            type: MaterialType.transparency,
            borderRadius: BorderRadius.circular(18),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              key: key,
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: Ink(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: child,
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 138,
      child: Row(
        key: const Key('home-highlight-row'),
        children: [
          entry(
            key: const Key('weekly-hot-entry'),
            label: 'AI 视频工作流，开始学习',
            colors: const [Color(0xFF4030B4), Color(0xFF6250D4)],
            onTap: onVideo,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'AI 视频工作流',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0x33FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        CupertinoIcons.play_fill,
                        color: Colors.white,
                        size: 15,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  '从分镜到成片',
                  style: TextStyle(color: Color(0xFFF0EEFF), fontSize: 12),
                ),
                const SizedBox(height: 7),
                const Text(
                  '开始学习  ›',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          entry(
            key: const Key('active-group-entry'),
            label: '产品设计共创群，18,420 人，加入群',
            colors: const [Color(0xFFFFFFFF), Color(0xFFF2EFFF)],
            onTap: onGroup,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ChatAvatar.group(
                      key: Key('home-design-group-avatar'),
                      members: ['Luna Design', 'Ada Product', '林木 Design'],
                      radius: 18,
                    ),
                    Spacer(),
                    Icon(
                      CupertinoIcons.chevron_right,
                      color: Color(0xFF777B8A),
                      size: 16,
                    ),
                  ],
                ),
                Spacer(),
                Text(
                  '产品设计共创群',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF17213A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 7),
                Row(
                  children: [
                    Text(
                      '18,420 人',
                      style: TextStyle(color: Color(0xFF777B8A), fontSize: 12),
                    ),
                    Spacer(),
                    Text(
                      '加入群',
                      style: TextStyle(
                        color: Color(0xFF6957E8),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoPostCard extends StatelessWidget {
  const _VideoPostCard({
    required this.playing,
    required this.followed,
    required this.joined,
    required this.liked,
    required this.bookmarked,
    required this.onPlay,
    required this.onFollow,
    required this.onJoin,
    required this.onLike,
    required this.onBookmark,
    required this.onComment,
    required this.onShare,
  });

  final bool playing;
  final bool followed;
  final bool joined;
  final bool liked;
  final bool bookmarked;
  final VoidCallback onPlay;
  final VoidCallback onFollow;
  final VoidCallback onJoin;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return _PostSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorRow(
            initial: 'K',
            name: 'Kevin AI',
            subtitle: 'AI 视频创作者 · 12 分钟前',
            followed: followed,
            onFollow: onFollow,
          ),
          const SizedBox(height: 14),
          const Text(
            '用 AI 制作短视频，我最常用的 5 个步骤',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            key: const Key('video-play'),
            borderRadius: BorderRadius.circular(4),
            onTap: onPlay,
            child: Align(
              alignment: Alignment.centerLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 252),
                child: AspectRatio(
                  key: const Key('moments-video-media'),
                  aspectRatio: 4 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _DeferredAssetImage(
                          'assets/images/ai-video-workflow.png',
                          key: const Key('post-image-ai-video'),
                          debugKeyPrefix: 'post-image-ai-video',
                          fit: BoxFit.cover,
                          semanticLabel: 'AI 视频创作工作台示例图',
                        ),
                        ColoredBox(color: Colors.black.withValues(alpha: 0.18)),
                        Center(
                          child: Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.42),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.9),
                                width: 1.5,
                              ),
                            ),
                            child: Icon(
                              playing
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 34,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 7,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: const Text(
                              '00:36',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 13),
          _CommunityLink(
            icon: Icons.forum_rounded,
            title: 'AI 视频创作者交流群',
            meta: '2,856 位成员',
            joined: joined,
            onTap: onJoin,
          ),
          const SizedBox(height: 12),
          _ActionRow(
            postId: 'video',
            likes: '1.2k',
            comments: '286',
            liked: liked,
            bookmarked: bookmarked,
            onLike: onLike,
            onComment: onComment,
            onBookmark: onBookmark,
            onShare: onShare,
          ),
        ],
      ),
    );
  }
}

class _ArticlePostCard extends StatelessWidget {
  const _ArticlePostCard({
    required this.followed,
    required this.joined,
    required this.liked,
    required this.bookmarked,
    required this.onFollow,
    required this.onJoin,
    required this.onLike,
    required this.onBookmark,
    required this.onComment,
    required this.onShare,
  });

  final bool followed;
  final bool joined;
  final bool liked;
  final bool bookmarked;
  final VoidCallback onFollow;
  final VoidCallback onJoin;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onComment;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return _PostSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorRow(
            initial: 'L',
            name: 'Luna Design',
            subtitle: '产品设计师 · 35 分钟前',
            followed: followed,
            onFollow: onFollow,
          ),
          const SizedBox(height: 14),
          const Text(
            '社区产品如何把内容浏览变成真实关系？',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 9),
          const Text(
            '内容只是入口。用户愿意加入讨论、认识同好并持续回来，社区才真正产生价值。',
            style: TextStyle(color: Color(0xFF626570), height: 1.55),
          ),
          const SizedBox(height: 8),
          const _CommunityImageGrid(
            images: [
              'assets/images/community-design-lucky-king.jpg',
              'assets/images/community-design-match.jpg',
            ],
          ),
          const SizedBox(height: 10),
          const Wrap(spacing: 8, children: [_Tag('#产品设计'), _Tag('#社区运营')]),
          const SizedBox(height: 13),
          _CommunityLink(
            icon: Icons.groups_2_rounded,
            title: '产品设计交流社区',
            meta: '18,420 位成员',
            joined: joined,
            onTap: onJoin,
          ),
          const SizedBox(height: 12),
          _ActionRow(
            postId: 'article',
            likes: '568',
            comments: '92',
            liked: liked,
            bookmarked: bookmarked,
            onLike: onLike,
            onComment: onComment,
            onBookmark: onBookmark,
            onShare: onShare,
          ),
        ],
      ),
    );
  }
}

class _SamplePostCard extends StatelessWidget {
  const _SamplePostCard({
    super.key,
    required this.post,
    required this.followed,
    required this.liked,
    required this.bookmarked,
    required this.onFollow,
    required this.onLike,
    required this.onBookmark,
    required this.onComment,
    required this.onShare,
    this.joined = false,
    this.onJoin,
  });

  final _SamplePostData post;
  final bool followed;
  final bool liked;
  final bool bookmarked;
  final VoidCallback onFollow;
  final VoidCallback onLike;
  final VoidCallback onBookmark;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final bool joined;
  final VoidCallback? onJoin;

  @override
  Widget build(BuildContext context) {
    return _PostSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AuthorRow(
            initial: post.author.characters.first,
            name: post.author,
            subtitle: '${post.role} · ${post.time}',
            followed: followed,
            onFollow: onFollow,
          ),
          const SizedBox(height: 14),
          Text(
            post.content,
            style: const TextStyle(
              color: Color(0xFF353740),
              fontSize: 15,
              height: 1.55,
            ),
          ),
          if (post.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            _CommunityImageGrid(
              keyPrefix: 'sample-${post.id}',
              images: post.images,
            ),
          ],
          SizedBox(height: post.images.isEmpty ? 12 : 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: post.tags.map((tag) => _Tag(tag)).toList(),
          ),
          if (post.groupName != null && onJoin != null) ...[
            const SizedBox(height: 13),
            _CommunityLink(
              icon: Icons.groups_2_rounded,
              title: post.groupName!,
              meta: '${post.groupMemberCount ?? '1'} 位成员',
              joined: joined,
              onTap: onJoin!,
            ),
          ],
          const SizedBox(height: 12),
          _ActionRow(
            postId: 'sample-${post.id}',
            likes: post.likes,
            comments: post.comments,
            liked: liked,
            bookmarked: bookmarked,
            onLike: onLike,
            onComment: onComment,
            onBookmark: onBookmark,
            onShare: onShare,
          ),
        ],
      ),
    );
  }
}

class _CommunityImageGrid extends StatelessWidget {
  const _CommunityImageGrid({
    required this.images,
    this.keyPrefix = 'post-image-community-design',
  });

  final List<String> images;
  final String keyPrefix;

  int get columnCount {
    if (images.length <= 3) return images.length;
    if (images.length == 4) return 2;
    return 3;
  }

  void openPreview(BuildContext context, int initialIndex) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            _ImagePreviewScreen(images: images, initialIndex: initialIndex),
        transitionsBuilder: (context, animation, secondaryAnimation, child) =>
            child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleImages = images.take(9).toList(growable: false);
    if (visibleImages.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 4.0;
        final columns = columnCount;
        final availableWidth = constraints.maxWidth;
        final cellSize = images.length == 1
            ? availableWidth.clamp(0.0, 240.0)
            : ((availableWidth.clamp(0.0, 288.0) - spacing * (columns - 1)) /
                  columns);
        final gridWidth = images.length == 1
            ? cellSize
            : cellSize * columns + spacing * (columns - 1);
        final rows = (visibleImages.length / columns).ceil();
        final singleImageHeight = cellSize * 0.78;

        return Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(
            key: Key(keyPrefix),
            width: gridWidth,
            height: images.length == 1
                ? singleImageHeight
                : rows * cellSize + (rows - 1) * spacing,
            child: GridView.builder(
              key: Key('$keyPrefix-grid'),
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: visibleImages.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: images.length == 1
                    ? cellSize / singleImageHeight
                    : 1,
              ),
              itemBuilder: (context, index) {
                final asset = visibleImages[index];
                return Semantics(
                  button: true,
                  label: '预览社区成员协作设计场景图 ${index + 1}',
                  child: GestureDetector(
                    key: Key('$keyPrefix-${index + 1}'),
                    onTap: () => openPreview(context, index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: _DeferredAssetImage(
                        asset,
                        debugKeyPrefix: '$keyPrefix-${index + 1}',
                        fit: BoxFit.cover,
                        alignment: Alignment.topCenter,
                        expandToFill: true,
                        displayImmediately: true,
                        semanticLabel: '社区成员协作设计场景图 ${index + 1}',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _DeferredAssetImage extends StatefulWidget {
  const _DeferredAssetImage(
    this.asset, {
    super.key,
    required this.debugKeyPrefix,
    required this.fit,
    required this.semanticLabel,
    this.alignment = Alignment.center,
    this.expandToFill = false,
    this.displayImmediately = false,
  });

  final String asset;
  final String debugKeyPrefix;
  final BoxFit fit;
  final String semanticLabel;
  final AlignmentGeometry alignment;
  final bool expandToFill;
  final bool displayImmediately;

  @override
  State<_DeferredAssetImage> createState() => _DeferredAssetImageState();
}

class _DeferredAssetImageState extends State<_DeferredAssetImage> {
  bool loadStarted = false;
  bool loaded = false;
  bool failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.displayImmediately) return;
    if (loadStarted) return;
    loadStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => loadImage());
  }

  Future<void> loadImage() async {
    var loadFailed = false;
    try {
      await precacheImage(
        AssetImage(widget.asset),
        context,
        onError: (error, stackTrace) => loadFailed = true,
      );
    } catch (_) {
      loadFailed = true;
    }
    if (!mounted) return;
    setState(() {
      failed = loadFailed;
      loaded = !loadFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.displayImmediately) {
      return Image.asset(
        widget.asset,
        key: Key('${widget.debugKeyPrefix}-loaded'),
        width: widget.expandToFill ? double.infinity : null,
        height: widget.expandToFill ? double.infinity : null,
        fit: widget.fit,
        alignment: widget.alignment,
        gaplessPlayback: true,
        semanticLabel: widget.semanticLabel,
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          key: Key('${widget.debugKeyPrefix}-failed'),
          color: const Color(0xFFF0F0F4),
          child: const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, color: Color(0xFF92949E)),
                SizedBox(height: 5),
                Text(
                  '图片加载失败',
                  style: TextStyle(color: Color(0xFF92949E), fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 160),
      child: failed
          ? ColoredBox(
              key: Key('${widget.debugKeyPrefix}-failed'),
              color: const Color(0xFFF0F0F4),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined, color: Color(0xFF92949E)),
                    SizedBox(height: 5),
                    Text(
                      '图片加载失败',
                      style: TextStyle(color: Color(0xFF92949E), fontSize: 11),
                    ),
                  ],
                ),
              ),
            )
          : loaded
          ? Image(
              key: Key('${widget.debugKeyPrefix}-loaded'),
              image: AssetImage(widget.asset),
              width: widget.expandToFill ? double.infinity : null,
              height: widget.expandToFill ? double.infinity : null,
              fit: widget.fit,
              alignment: widget.alignment,
              gaplessPlayback: true,
              semanticLabel: widget.semanticLabel,
            )
          : ColoredBox(
              key: Key('${widget.debugKeyPrefix}-placeholder'),
              color: const Color(0xFFF0F0F4),
              child: const Center(
                child: Icon(Icons.image_outlined, color: Color(0xFFB0B1BA)),
              ),
            ),
    );
  }
}

class _ImagePreviewScreen extends StatefulWidget {
  const _ImagePreviewScreen({required this.images, required this.initialIndex});

  final List<String> images;
  final int initialIndex;

  @override
  State<_ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<_ImagePreviewScreen> {
  late final PageController pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const Key('community-image-preview'),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              key: const Key('community-image-preview-pages'),
              controller: pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) => setState(() => currentIndex = index),
              itemBuilder: (context, index) {
                final asset = widget.images[index];
                return _ZoomablePreviewImage(
                  key: Key('community-preview-image-${index + 1}'),
                  asset: asset,
                );
              },
            ),
            Positioned(
              left: 8,
              top: 4,
              child: IconButton(
                key: const Key('close-community-image-preview'),
                tooltip: '返回',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: Colors.white,
              ),
            ),
            Positioned(
              left: 64,
              right: 64,
              top: 14,
              child: Text(
                '${currentIndex + 1} / ${widget.images.length}',
                key: const Key('community-image-preview-count'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ZoomablePreviewImage extends StatefulWidget {
  const _ZoomablePreviewImage({super.key, required this.asset});

  final String asset;

  @override
  State<_ZoomablePreviewImage> createState() => _ZoomablePreviewImageState();
}

class _ZoomablePreviewImageState extends State<_ZoomablePreviewImage> {
  final transformationController = TransformationController();
  bool zoomed = false;

  @override
  void dispose() {
    transformationController.dispose();
    super.dispose();
  }

  void toggleZoom() {
    setState(() {
      zoomed = !zoomed;
      transformationController.value = zoomed
          ? Matrix4.diagonal3Values(2.5, 2.5, 1)
          : Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTap: toggleZoom,
      child: InteractiveViewer(
        key: Key('zoomable-${widget.asset}'),
        transformationController: transformationController,
        minScale: 1,
        maxScale: 4,
        panEnabled: zoomed,
        onInteractionEnd: (details) {
          final isZoomed =
              transformationController.value.getMaxScaleOnAxis() > 1;
          if (isZoomed != zoomed) setState(() => zoomed = isZoomed);
        },
        child: Center(
          child: Image.asset(
            widget.asset,
            width: double.infinity,
            fit: BoxFit.contain,
            semanticLabel: '全屏图片预览',
          ),
        ),
      ),
    );
  }
}

class _PostSurface extends StatelessWidget {
  const _PostSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B161A2D),
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: child,
  );
}

class _AuthorRow extends StatelessWidget {
  const _AuthorRow({
    required this.initial,
    required this.name,
    required this.subtitle,
    required this.followed,
    required this.onFollow,
  });
  final String initial;
  final String name;
  final String subtitle;
  final bool followed;
  final VoidCallback onFollow;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      ChatAvatar.person(
        key: Key('home-author-avatar-$name'),
        name: name,
        radius: 20,
      ),
      const SizedBox(width: 11),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 12, color: Color(0xFF989AA4)),
            ),
          ],
        ),
      ),
      TextButton(
        key: Key('follow-$name'),
        onPressed: onFollow,
        child: Text(
          followed ? '已关注' : '+ 关注',
          style: TextStyle(
            color: followed ? const Color(0xFF8A8D98) : const Color(0xFF6356E6),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _CommunityLink extends StatelessWidget {
  const _CommunityLink({
    required this.icon,
    required this.title,
    required this.meta,
    required this.joined,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String meta;
  final bool joined;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('community-$title'),
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Ink(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F4FF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF6256E8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B8D98),
                  ),
                ),
              ],
            ),
          ),
          Text(
            joined ? '已加入' : '加入',
            style: TextStyle(
              color: joined ? const Color(0xFF8A8D98) : const Color(0xFF6256E8),
              fontWeight: FontWeight.w700,
            ),
          ),
          Icon(
            joined ? Icons.check_rounded : Icons.chevron_right_rounded,
            color: Color(0xFF6256E8),
          ),
        ],
      ),
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.postId,
    required this.likes,
    required this.comments,
    required this.liked,
    required this.bookmarked,
    required this.onLike,
    required this.onComment,
    required this.onBookmark,
    required this.onShare,
  });
  final String postId;
  final String likes;
  final String comments;
  final bool liked;
  final bool bookmarked;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onBookmark;
  final VoidCallback onShare;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        key: Key('like-$postId'),
        visualDensity: VisualDensity.compact,
        onPressed: onLike,
        icon: Icon(
          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 21,
          color: liked ? const Color(0xFFFF4D67) : null,
        ),
      ),
      const SizedBox(width: 5),
      Text(likes),
      const SizedBox(width: 12),
      IconButton(
        key: Key('comment-$postId'),
        visualDensity: VisualDensity.compact,
        onPressed: onComment,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
      ),
      const SizedBox(width: 5),
      Text(comments),
      const SizedBox(width: 12),
      IconButton(
        key: Key('bookmark-$postId'),
        visualDensity: VisualDensity.compact,
        onPressed: onBookmark,
        icon: Icon(
          bookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          size: 21,
          color: bookmarked ? const Color(0xFF6256E8) : null,
        ),
      ),
      const Spacer(),
      IconButton(
        key: Key('share-$postId'),
        visualDensity: VisualDensity.compact,
        onPressed: onShare,
        icon: const Icon(Icons.ios_share_rounded, size: 20),
      ),
    ],
  );
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F2F6),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 12, color: Color(0xFF666975)),
    ),
  );
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.onPublish,
  });

  final int selectedIndex;
  final void Function(int index, String label) onSelected;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.fromLTRB(10, 0, 10, 7),
    child: SizedBox(
      key: const Key('ios-glass-tab-bar'),
      height: 72,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(29),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x240F172A),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Color(0x12FFFFFF),
                    blurRadius: 2,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: ClipRRect(
                key: const Key('ios-glass-tab-surface'),
                borderRadius: BorderRadius.circular(29),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(29),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _NavItem(
                            icon: Icons.home_outlined,
                            selectedIcon: Icons.home_rounded,
                            label: '首页',
                            selected: selectedIndex == 0,
                            onTap: () => onSelected(0, '首页'),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.video_library_outlined,
                            selectedIcon: Icons.video_library_rounded,
                            label: '视频',
                            selected: selectedIndex == 1,
                            onTap: () => onSelected(1, '视频'),
                          ),
                        ),
                        const SizedBox(width: 52),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.forum_outlined,
                            selectedIcon: Icons.forum_rounded,
                            label: '消息',
                            selected: selectedIndex == 2,
                            onTap: () => onSelected(2, '消息'),
                          ),
                        ),
                        Expanded(
                          child: _NavItem(
                            icon: Icons.account_circle_outlined,
                            selectedIcon: Icons.account_circle_rounded,
                            label: '我的',
                            selected: selectedIndex == 3,
                            onTap: () => onSelected(3, '我的'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(top: 7, child: _PublishButton(onTap: onPublish)),
        ],
      ),
    ),
  );
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('nav-$label'),
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF6256E8).withValues(alpha: 0.07)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: selected ? 1.06 : 1,
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutBack,
                child: Icon(
                  selected ? selectedIcon : icon,
                  size: 25,
                  color: selected
                      ? const Color(0xFF6256E8)
                      : const Color(0xFF9698A2),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  height: 1,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? const Color(0xFF6256E8)
                      : const Color(0xFF9698A2),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ClipOval(
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Material(
        color: Colors.white.withValues(alpha: 0.8),
        child: InkWell(
          key: const Key('nav-publish'),
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.5,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260F172A),
                  blurRadius: 12,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Color(0xFF6256E8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 27,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
