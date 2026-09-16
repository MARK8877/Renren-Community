import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
import '../auth/auth_session.dart';
import '../widgets/chat_avatar.dart';
import 'video_feed_screen.dart';

enum _ProfileFeatureKind {
  generic,
  following,
  followers,
  likes,
  creatorCenter,
  revenue,
  wallet,
  communities,
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int selectedTab = 0;
  late String nickname;
  late final TextEditingController nicknameController;
  late final TextEditingController bioController;
  final tabSectionKey = GlobalKey();
  String bio = '分享创作过程，也在这里认识同频的人。';

  static const tabLabels = ['作品', '动态', '收藏'];
  static const previewAssets = [
    'assets/images/ai-video-workflow.png',
    'assets/images/community-design-collaboration.png',
    'assets/images/community-design-match.jpg',
    'assets/images/community-design-lucky-king.jpg',
  ];

  @override
  void initState() {
    super.initState();
    nickname = widget.session.nickname;
    nicknameController = TextEditingController(text: nickname);
    bioController = TextEditingController(text: bio);
    loadProfile();
  }

  @override
  void dispose() {
    nicknameController.dispose();
    bioController.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> loadProfile() async {
    if (!widget.session.signedIn) return;
    try {
      final profile = await widget.session.getProfile();
      if (!mounted) return;
      setState(() {
        nickname = profile.nickname;
        bio = profile.bio;
      });
    } on AuthException {
      // 保留本地登录信息，避免资料接口短暂失败阻断页面使用。
    }
  }

  Future<void> editProfile() async {
    nicknameController.text = nickname;
    bioController.text = bio;
    final saved = await showModalBottomSheet<UserProfile>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '编辑个人资料',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            TextField(
              key: const Key('profile-nickname-input'),
              controller: nicknameController,
              maxLength: 20,
              decoration: const InputDecoration(labelText: '昵称'),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('profile-bio-input'),
              controller: bioController,
              maxLength: 60,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '个人简介'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('save-profile'),
                onPressed: () async {
                  final nextNickname = nicknameController.text.trim();
                  if (nextNickname.isEmpty) return;
                  try {
                    final profile = await widget.session.updateProfile(
                      nickname: nextNickname,
                      bio: bioController.text.trim(),
                    );
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext, profile);
                    }
                  } on AuthException catch (error) {
                    if (mounted) showMessage(error.message);
                  }
                },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved != null && mounted) {
      setState(() {
        nickname = saved.nickname;
        bio = saved.bio;
      });
      showMessage('个人资料已更新');
    }
  }

  void openFeature(
    String title,
    String description,
    IconData icon, {
    _ProfileFeatureKind kind = _ProfileFeatureKind.generic,
  }) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _ProfileFeaturePage(
          title: title,
          description: description,
          icon: icon,
          kind: kind,
        ),
      ),
    );
  }

  void openSettings() {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _ProfileSettingsPage(session: widget.session),
      ),
    );
  }

  void openWorkVideo(int index) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            VideoFeedScreen(session: widget.session, initialIndex: index),
      ),
    );
  }

  void selectTab(int index) => setState(() => selectedTab = index);

  void openContentTab(int index) {
    selectTab(index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabContext = tabSectionKey.currentContext;
      if (tabContext == null) return;
      Scrollable.ensureVisible(
        tabContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7FA),
      body: SafeArea(
        key: const Key('profile-main-screen'),
        child: CustomScrollView(
          key: const PageStorageKey<String>('profile-scroll'),
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: const Color(0xFFF7F7FA),
              surfaceTintColor: const Color(0xFFF7F7FA),
              title: const Text(
                '我的',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: [
                IconButton(
                  key: const Key('profile-settings'),
                  tooltip: '设置',
                  onPressed: openSettings,
                  icon: const Icon(Icons.settings_outlined),
                ),
                const SizedBox(width: 6),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              sliver: SliverList.list(
                children: [
                  _ProfileHeader(
                    nickname: nickname,
                    avatarName: widget.session.nickname,
                    bio: bio,
                    onEdit: editProfile,
                    onFollowing: () => openFeature(
                      '我的关注',
                      '查看已关注的创作者和朋友',
                      Icons.person_add_alt_1_rounded,
                      kind: _ProfileFeatureKind.following,
                    ),
                    onFollowers: () => openFeature(
                      '我的粉丝',
                      '查看关注你的社区成员',
                      Icons.groups_rounded,
                      kind: _ProfileFeatureKind.followers,
                    ),
                    onLikes: () => openFeature(
                      '获赞记录',
                      '查看作品和动态获得的点赞',
                      Icons.favorite_rounded,
                      kind: _ProfileFeatureKind.likes,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _CreatorTools(
                    onCreatorCenter: () => openFeature(
                      '创作者中心',
                      '今日播放 3,286，新增粉丝 46',
                      Icons.auto_awesome_rounded,
                      kind: _ProfileFeatureKind.creatorCenter,
                    ),
                    onRevenue: () => openFeature(
                      '收益中心',
                      '本月预估收益 ¥1,268.50',
                      Icons.trending_up_rounded,
                      kind: _ProfileFeatureKind.revenue,
                    ),
                    onWallet: () => openFeature(
                      '我的钱包',
                      '可用余额 ¥386.20',
                      Icons.account_balance_wallet_rounded,
                      kind: _ProfileFeatureKind.wallet,
                    ),
                    onCommunities: () => openFeature(
                      '我的社区',
                      '管理已加入的社区和群聊',
                      Icons.forum_rounded,
                      kind: _ProfileFeatureKind.communities,
                    ),
                  ),
                  const SizedBox(height: 8),
                  KeyedSubtree(
                    key: const Key('profile-content-tabs'),
                    child: _ProfileTabs(
                      key: tabSectionKey,
                      selected: selectedTab,
                      onSelected: selectTab,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfileTabContent(
                    key: ValueKey('profile-tab-$selectedTab'),
                    selectedTab: selectedTab,
                    assets: previewAssets,
                    onOpenVideo: openWorkVideo,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.nickname,
    required this.avatarName,
    required this.bio,
    required this.onEdit,
    required this.onFollowing,
    required this.onFollowers,
    required this.onLikes,
  });

  final String nickname;
  final String avatarName;
  final String bio;
  final VoidCallback onEdit;
  final VoidCallback onFollowing;
  final VoidCallback onFollowers;
  final VoidCallback onLikes;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('profile-header'),
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF6758EA), Color(0xFF9B63EE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              alignment: Alignment.center,
              child: ChatAvatar.person(
                key: const Key('profile-avatar'),
                name: avatarName,
                radius: 32,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              key: const Key('profile-identity-info'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          nickname,
                          key: const Key('profile-nickname'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '创作者',
                          style: TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '像素号：PX20260908',
                    style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    bio,
                    key: const Key('profile-bio'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xD9FFFFFF),
                      fontSize: 12,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              key: const Key('edit-profile'),
              onPressed: onEdit,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xB3FFFFFF)),
                minimumSize: const Size(58, 34),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('编辑'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _StatsCard(
          key: const Key('profile-header-stats'),
          onFollowing: onFollowing,
          onFollowers: onFollowers,
          onLikes: onLikes,
        ),
      ],
    ),
  );
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    super.key,
    required this.onFollowing,
    required this.onFollowers,
    required this.onLikes,
  });

  final VoidCallback onFollowing;
  final VoidCallback onFollowers;
  final VoidCallback onLikes;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: Color(0x40FFFFFF))),
    ),
    padding: const EdgeInsets.only(top: 2),
    child: Row(
      children: [
        _StatItem(label: '关注', value: '24', onTap: onFollowing),
        const _VerticalDivider(),
        _StatItem(label: '粉丝', value: '1,286', onTap: onFollowers),
        const _VerticalDivider(),
        _StatItem(label: '获赞', value: '8.6万', onTap: onLikes),
      ],
    ),
  );
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      key: Key('profile-stat-$label'),
      onTap: onTap,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 12),
          ),
        ],
      ),
    ),
  );
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();
  @override
  Widget build(BuildContext context) => const SizedBox(
    height: 30,
    child: VerticalDivider(color: Color(0x40FFFFFF)),
  );
}

class _CreatorTools extends StatelessWidget {
  const _CreatorTools({
    required this.onCreatorCenter,
    required this.onRevenue,
    required this.onWallet,
    required this.onCommunities,
  });

  final VoidCallback onCreatorCenter;
  final VoidCallback onRevenue;
  final VoidCallback onWallet;
  final VoidCallback onCommunities;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('profile-tools-grid'),
    padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '创作者工具',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ToolItem(
                key: const Key('creator-center'),
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFF6256E8),
                title: '创作者中心',
                metric: '今日 3.2k',
                onTap: onCreatorCenter,
              ),
            ),
            Expanded(
              child: _ToolItem(
                key: const Key('revenue-center'),
                icon: Icons.trending_up_rounded,
                color: const Color(0xFFF28B62),
                title: '收益中心',
                metric: '¥1,268',
                onTap: onRevenue,
              ),
            ),
            Expanded(
              child: _ToolItem(
                key: const Key('wallet'),
                icon: Icons.account_balance_wallet_outlined,
                color: const Color(0xFFE2A323),
                title: '钱包',
                metric: '¥386',
                onTap: onWallet,
              ),
            ),
            Expanded(
              child: _ToolItem(
                key: const Key('profile-communities'),
                icon: Icons.forum_outlined,
                color: const Color(0xFF28A887),
                title: '我的社区',
                metric: '6 个',
                onTap: onCommunities,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _ToolItem extends StatelessWidget {
  const _ToolItem({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.metric,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String metric;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 7),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            metric,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Color(0xFF858A98)),
          ),
        ],
      ),
    ),
  );
}

class _ProfileTabs extends StatelessWidget {
  const _ProfileTabs({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: List.generate(_ProfileScreenState.tabLabels.length, (index) {
      final label = _ProfileScreenState.tabLabels[index];
      final active = selected == index;
      return Expanded(
        child: InkWell(
          key: Key('profile-tab-$label'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelected(index),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Column(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: active
                        ? const Color(0xFF6256E8)
                        : const Color(0xFF7D7F89),
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: active ? 24 : 0,
                  height: 3,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6256E8),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }),
  );
}

class _ProfileTabContent extends StatelessWidget {
  const _ProfileTabContent({
    super.key,
    required this.selectedTab,
    required this.assets,
    required this.onOpenVideo,
  });
  final int selectedTab;
  final List<String> assets;
  final ValueChanged<int> onOpenVideo;

  @override
  Widget build(BuildContext context) {
    if (selectedTab == 1) {
      return Column(
        key: const Key('profile-dynamic-list'),
        children: const [
          _DynamicPreview(text: '今天完成了一轮社区首页共创评审。'),
          SizedBox(height: 10),
          _DynamicPreview(text: '新的 AI 视频工作流已经整理完成。'),
        ],
      );
    }

    final count = selectedTab == 0 ? 6 : 4;
    return GridView.builder(
      key: Key(selectedTab == 0 ? 'profile-works-grid' : 'profile-saved-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: count,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (context, index) => Semantics(
        button: selectedTab == 0,
        label: selectedTab == 0 ? '播放作品 ${index + 1}' : '收藏内容 ${index + 1}',
        child: GestureDetector(
          key: Key(
            selectedTab == 0
                ? 'profile-work-${index + 1}'
                : 'profile-saved-${index + 1}',
          ),
          onTap: selectedTab == 0 ? () => onOpenVideo(index) : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(assets[index % assets.length], fit: BoxFit.cover),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.center,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0x99000000)],
                    ),
                  ),
                ),
                if (selectedTab == 0)
                  const Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      color: Color(0xE6FFFFFF),
                      size: 34,
                      shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                    ),
                  ),
                Positioned(
                  left: 7,
                  bottom: 6,
                  child: Row(
                    children: [
                      Icon(
                        selectedTab == 0
                            ? Icons.play_arrow_rounded
                            : Icons.favorite_rounded,
                        color: Colors.white,
                        size: 15,
                      ),
                      Text(
                        '${(index + 1) * 1.2}k',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DynamicPreview extends StatelessWidget {
  const _DynamicPreview({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 10),
        const Text(
          '2 小时前  ·  18 赞  6 评论',
          style: TextStyle(color: Color(0xFF90929C), fontSize: 12),
        ),
      ],
    ),
  );
}

class _ProfileFeaturePage extends StatelessWidget {
  const _ProfileFeaturePage({
    required this.title,
    required this.description,
    required this.icon,
    this.kind = _ProfileFeatureKind.generic,
  });
  final String title;
  final String description;
  final IconData icon;
  final _ProfileFeatureKind kind;

  @override
  Widget build(BuildContext context) {
    if (kind == _ProfileFeatureKind.creatorCenter) {
      return _CreatorDashboardPage(
        title: title,
        description: description,
        icon: icon,
      );
    }
    if (kind == _ProfileFeatureKind.revenue) {
      return _RevenueDashboardPage(
        title: title,
        description: description,
        icon: icon,
      );
    }
    if (kind == _ProfileFeatureKind.wallet) {
      return _WalletDashboardPage(
        title: title,
        description: description,
        icon: icon,
      );
    }
    if (kind == _ProfileFeatureKind.communities) {
      return _CommunitiesDashboardPage(
        title: title,
        description: description,
        icon: icon,
      );
    }
    if (kind == _ProfileFeatureKind.following) {
      return const _ConnectionsPage(
        pageKey: Key('profile-following-page'),
        title: '我的关注',
        countLabel: '24 位创作者',
        description: '持续发现与你同频的创作伙伴',
        actionLabel: '已关注',
      );
    }
    if (kind == _ProfileFeatureKind.followers) {
      return const _ConnectionsPage(
        pageKey: Key('profile-followers-page'),
        title: '我的粉丝',
        countLabel: '1,286 位粉丝',
        description: '和关注你的人保持真诚互动',
        actionLabel: '回关',
      );
    }
    if (kind == _ProfileFeatureKind.likes) {
      return const _LikesPage(
        pageKey: Key('profile-likes-page'),
        title: '获赞记录',
        countLabel: '8.6万 获赞',
        description: '来自作品和动态的每一次回应',
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EEFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Icon(icon, size: 48, color: const Color(0xFF6256E8)),
                const SizedBox(height: 14),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(description, textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < 3; index++)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text('$title项目 ${index + 1}'),
                subtitle: const Text('点击查看详情'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceScaffold extends StatelessWidget {
  const _WorkspaceScaffold({
    required this.pageKey,
    required this.title,
    required this.children,
  });

  final Key pageKey;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    key: pageKey,
    backgroundColor: const Color(0xFFF4F7FC),
    appBar: AppBar(
      backgroundColor: const Color(0xFFF4F7FC),
      surfaceTintColor: Colors.transparent,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: children,
    ),
  );
}

class _WorkspaceHero extends StatelessWidget {
  const _WorkspaceHero({
    required this.label,
    required this.title,
    required this.description,
    required this.icon,
    required this.child,
  });

  final String label;
  final String title;
  final String description;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    decoration: BoxDecoration(
      color: const Color(0xFF172033),
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A172033),
          blurRadius: 16,
          offset: Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF95C8F4),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(icon, color: Color(0xFF95C8F4), size: 22),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: const TextStyle(color: Color(0xB8FFFFFF), fontSize: 13),
        ),
        const SizedBox(height: 18),
        child,
      ],
    ),
  );
}

class _HeroMetricRow extends StatelessWidget {
  const _HeroMetricRow({required this.metrics});

  final List<(String, String)> metrics;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var index = 0; index < metrics.length; index++) ...[
        if (index > 0) const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metrics[index].$1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  metrics[index].$2,
                  style: const TextStyle(
                    color: Color(0x99FFFFFF),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ],
  );
}

class _WorkspaceSectionTitle extends StatelessWidget {
  const _WorkspaceSectionTitle(this.title, {this.action});

  final String title;
  final String? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF172033),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (action != null)
          Text(
            action!,
            style: const TextStyle(
              color: Color(0xFF3D7CF4),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    ),
  );
}

class _WorkspaceAction extends StatelessWidget {
  const _WorkspaceAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.color = const Color(0xFF3D7CF4),
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDDE5F1)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 3),
        Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Color(0xFF778196), fontSize: 11),
        ),
      ],
    ),
  );
}

class _WorkspaceListRow extends StatelessWidget {
  const _WorkspaceListRow({
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.icon,
    this.trailingColor = const Color(0xFF3D7CF4),
  });

  final String title;
  final String subtitle;
  final String trailing;
  final IconData? icon;
  final Color trailingColor;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE3EAF4)),
    ),
    child: Row(
      children: [
        if (icon != null) ...[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0x1495C8F4),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF3D7CF4), size: 19),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF778196), fontSize: 12),
              ),
            ],
          ),
        ),
        Text(
          trailing,
          style: TextStyle(color: trailingColor, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );
}

class _CreatorDashboardPage extends StatelessWidget {
  const _CreatorDashboardPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _WorkspaceScaffold(
    pageKey: const Key('creator-dashboard-page'),
    title: title,
    children: [
      _WorkspaceHero(
        label: '今日创作状态',
        title: '让作品继续被看见',
        description: description,
        icon: icon,
        child: const _HeroMetricRow(
          metrics: [('3,286', '播放'), ('46', '新增粉丝'), ('82%', '互动率')],
        ),
      ),
      const _WorkspaceSectionTitle('下一步'),
      const Row(
        children: [
          Expanded(
            child: _WorkspaceAction(
              icon: Icons.add_circle_outline_rounded,
              title: '发布新作品',
              subtitle: '记录新的灵感',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _WorkspaceAction(
              icon: Icons.insights_rounded,
              title: '查看数据',
              subtitle: '了解作品表现',
            ),
          ),
        ],
      ),
      const _WorkspaceSectionTitle('最近作品表现', action: '查看全部'),
      const _WorkspaceListRow(
        icon: Icons.play_circle_outline_rounded,
        title: 'AI 视频工作流',
        subtitle: '刚刚 · 持续获得互动',
        trailing: '+18%',
      ),
      const _WorkspaceListRow(
        icon: Icons.image_outlined,
        title: '社区协作设计',
        subtitle: '昨天 · 1,204 次播放',
        trailing: '+12%',
      ),
    ],
  );
}

class _RevenueDashboardPage extends StatelessWidget {
  const _RevenueDashboardPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _WorkspaceScaffold(
    pageKey: const Key('revenue-dashboard-page'),
    title: title,
    children: [
      _WorkspaceHero(
        label: '本月预估收益',
        title: '¥1,268.50',
        description: description,
        icon: icon,
        child: const _HeroMetricRow(
          metrics: [('¥820', '订阅'), ('¥318', '打赏'), ('¥130.5', '付费内容')],
        ),
      ),
      const _WorkspaceSectionTitle('收益来源'),
      const _WorkspaceListRow(
        icon: Icons.card_membership_rounded,
        title: '创作者订阅',
        subtitle: '本月 32 位订阅者',
        trailing: '¥820.00',
        trailingColor: Color(0xFFE59A42),
      ),
      const _WorkspaceListRow(
        icon: Icons.favorite_outline_rounded,
        title: '内容打赏',
        subtitle: '本月 86 次支持',
        trailing: '¥318.00',
        trailingColor: Color(0xFFE59A42),
      ),
      const _WorkspaceSectionTitle('最近收益', action: '全部记录'),
      const _WorkspaceListRow(
        title: '林木 Design 订阅',
        subtitle: '今天 10:24',
        trailing: '+¥29.00',
        trailingColor: Color(0xFFE59A42),
      ),
      const _WorkspaceListRow(
        title: 'AI 视频工作流打赏',
        subtitle: '昨天 18:21',
        trailing: '+¥18.00',
        trailingColor: Color(0xFFE59A42),
      ),
    ],
  );
}

class _WalletDashboardPage extends StatelessWidget {
  const _WalletDashboardPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _WorkspaceScaffold(
    pageKey: const Key('wallet-dashboard-page'),
    title: title,
    children: [
      _WorkspaceHero(
        label: '可用余额',
        title: '¥386.20',
        description: description,
        icon: icon,
        child: const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            '余额实时更新 · 可随时提现',
            style: TextStyle(color: Color(0xB8FFFFFF), fontSize: 12),
          ),
        ),
      ),
      const _WorkspaceSectionTitle('快捷操作'),
      const Row(
        children: [
          Expanded(
            child: _WorkspaceAction(
              icon: Icons.arrow_upward_rounded,
              title: '提现',
              subtitle: '转入银行卡',
              color: Color(0xFFE59A42),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _WorkspaceAction(
              icon: Icons.account_balance_wallet_outlined,
              title: '充值',
              subtitle: '补充钱包余额',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _WorkspaceAction(
              icon: Icons.receipt_long_outlined,
              title: '账单',
              subtitle: '查看明细',
            ),
          ),
        ],
      ),
      const _WorkspaceSectionTitle('最近交易', action: '全部账单'),
      const _WorkspaceListRow(
        icon: Icons.arrow_downward_rounded,
        title: '内容打赏收入',
        subtitle: '今天 10:24',
        trailing: '+¥29.00',
        trailingColor: Color(0xFF2D9C78),
      ),
      const _WorkspaceListRow(
        icon: Icons.arrow_upward_rounded,
        title: '提现至银行卡',
        subtitle: '昨天 16:40',
        trailing: '-¥100.00',
        trailingColor: Color(0xFFD46666),
      ),
    ],
  );
}

class _CommunitiesDashboardPage extends StatelessWidget {
  const _CommunitiesDashboardPage({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => _WorkspaceScaffold(
    pageKey: const Key('communities-dashboard-page'),
    title: title,
    children: [
      _WorkspaceHero(
        label: '社区空间',
        title: '6 个社区',
        description: description,
        icon: icon,
        child: const Text(
          '最近活跃：产品设计共创群 · 12 分钟前',
          style: TextStyle(color: Color(0xB8FFFFFF), fontSize: 12),
        ),
      ),
      const _WorkspaceSectionTitle('已加入的社区'),
      _CommunityRow(
        title: '产品设计共创群',
        subtitle: '1,284 位成员 · 12 分钟前活跃',
        names: const ['林木 Design', '阿北摄影', '小鹿同学'],
      ),
      _CommunityRow(
        title: 'AI 创作者交流',
        subtitle: '836 位成员 · 1 小时前活跃',
        names: const ['Kevin Fan', '林木 Design', '阿北摄影'],
      ),
      _CommunityRow(
        title: '摄影灵感库',
        subtitle: '492 位成员 · 昨天活跃',
        names: const ['小鹿同学', 'Kevin Fan', '林木 Design'],
      ),
    ],
  );
}

class _CommunityRow extends StatelessWidget {
  const _CommunityRow({
    required this.title,
    required this.subtitle,
    required this.names,
  });

  final String title;
  final String subtitle;
  final List<String> names;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE3EAF4)),
    ),
    child: Row(
      children: [
        _CommunityAvatarCluster(names: names),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(color: Color(0xFF778196), fontSize: 11),
              ),
            ],
          ),
        ),
        const Text(
          '进入社区',
          style: TextStyle(
            color: Color(0xFF3D7CF4),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _CommunityAvatarCluster extends StatelessWidget {
  const _CommunityAvatarCluster({required this.names});

  final List<String> names;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: Stack(
      children: [
        for (var index = 0; index < names.length; index++)
          Positioned(
            left: (index % 2) * 18,
            top: (index ~/ 2) * 18,
            child: Container(
              padding: const EdgeInsets.all(1.5),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: ChatAvatar.person(name: names[index], radius: 14),
            ),
          ),
      ],
    ),
  );
}

class _ConnectionsPage extends StatelessWidget {
  const _ConnectionsPage({
    required this.pageKey,
    required this.title,
    required this.countLabel,
    required this.description,
    required this.actionLabel,
  });

  final Key pageKey;
  final String title;
  final String countLabel;
  final String description;
  final String actionLabel;

  static const rows = [
    ('林木 Design', '产品设计 · 最近活跃'),
    ('阿北摄影', '影像创作 · 2 小时前'),
    ('小鹿同学', 'AI 创作 · 昨天活跃'),
    ('Kevin Fan', '独立开发 · 3 天前'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    key: pageKey,
    backgroundColor: const Color(0xFFF7F7FA),
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _FeatureSummary(
          icon: Icons.groups_rounded,
          title: countLabel,
          description: description,
          color: const Color(0xFF6256E8),
        ),
        const SizedBox(height: 16),
        const Text(
          '最近互动',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final row in rows)
          _ConnectionRow(
            name: row.$1,
            subtitle: row.$2,
            actionLabel: actionLabel,
            showFollowBack: actionLabel == '回关',
          ),
      ],
    ),
  );
}

class _ConnectionRow extends StatelessWidget {
  const _ConnectionRow({
    required this.name,
    required this.subtitle,
    required this.actionLabel,
    required this.showFollowBack,
  });

  final String name;
  final String subtitle;
  final String actionLabel;
  final bool showFollowBack;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        ChatAvatar.person(name: name, radius: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF858A98)),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: () {},
          style: TextButton.styleFrom(
            foregroundColor: showFollowBack
                ? const Color(0xFF6256E8)
                : const Color(0xFF858A98),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 34),
          ),
          child: Text(actionLabel),
        ),
      ],
    ),
  );
}

class _LikesPage extends StatelessWidget {
  const _LikesPage({
    required this.pageKey,
    required this.title,
    required this.countLabel,
    required this.description,
  });

  final Key pageKey;
  final String title;
  final String countLabel;
  final String description;

  static const activities = [
    (
      '林木 Design',
      '喜欢了你的 AI 视频工作流',
      '2 小时前',
      'assets/images/ai-video-workflow.png',
    ),
    (
      '阿北摄影',
      '喜欢了你的社区协作设计',
      '昨天 18:21',
      'assets/images/community-design-collaboration.png',
    ),
    ('小鹿同学', '喜欢了你的动态', '昨天 15:04', 'assets/images/community-design-match.jpg'),
    (
      'Kevin Fan',
      '喜欢了你的作品',
      '09-06',
      'assets/images/community-design-lucky-king.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    key: pageKey,
    backgroundColor: const Color(0xFFF7F7FA),
    appBar: AppBar(title: Text(title)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: [
        _FeatureSummary(
          icon: Icons.favorite_rounded,
          title: countLabel,
          description: description,
          color: const Color(0xFFF28B62),
        ),
        const SizedBox(height: 16),
        const Text(
          '最近获赞',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final activity in activities)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                ChatAvatar.person(name: activity.$1, radius: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.$1,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(activity.$2, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 3),
                      Text(
                        activity.$3,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF989BA5),
                        ),
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    activity.$4,
                    width: 54,
                    height: 54,
                    fit: BoxFit.cover,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

class _FeatureSummary extends StatelessWidget {
  const _FeatureSummary({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withValues(alpha: 0.16), Colors.white],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(color: Color(0xFF6F7585)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProfileSettingsPage extends StatefulWidget {
  const _ProfileSettingsPage({required this.session});
  final AuthSession session;
  @override
  State<_ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<_ProfileSettingsPage> {
  bool notificationsEnabled = true;
  bool privateAccount = false;

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-logout'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    Navigator.pop(context);
    await widget.session.logout();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('profile-settings-screen'),
    backgroundColor: const Color(0xFFF7F7FA),
    appBar: AppBar(title: const Text('设置')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: const Text('账号与安全'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showMessage('账号安全页已打开'),
              ),
              SwitchListTile(
                key: const Key('notification-setting'),
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('消息通知'),
                value: notificationsEnabled,
                onChanged: (value) =>
                    setState(() => notificationsEnabled = value),
              ),
              SwitchListTile(
                key: const Key('privacy-setting'),
                secondary: const Icon(Icons.lock_outline_rounded),
                title: const Text('隐私账号'),
                value: privateAccount,
                onChanged: (value) => setState(() => privateAccount = value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: const Text('通用设置'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showMessage('通用设置已打开'),
              ),
              ListTile(
                leading: const Icon(Icons.help_outline_rounded),
                title: const Text('帮助与反馈'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => showMessage('帮助与反馈已打开'),
              ),
              const ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('关于像素社区'),
                trailing: Text('V1.0.0'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton(
          key: const Key('logout-button'),
          onPressed: confirmLogout,
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFFE64646),
            side: const BorderSide(color: Color(0x33E64646)),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          child: const Text('退出登录'),
        ),
      ],
    ),
  );
}
