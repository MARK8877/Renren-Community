import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../widgets/chat_avatar.dart';
import 'video_feed_screen.dart';

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

  Future<void> editProfile() async {
    nicknameController.text = nickname;
    bioController.text = bio;
    final saved = await showModalBottomSheet<bool>(
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
                onPressed: () {
                  if (nicknameController.text.trim().isEmpty) return;
                  Navigator.pop(sheetContext, true);
                },
                child: const Text('保存'),
              ),
            ),
          ],
        ),
      ),
    );
    if (saved == true && mounted) {
      setState(() {
        nickname = nicknameController.text.trim();
        bio = bioController.text.trim();
      });
      showMessage('个人资料已更新');
    }
  }

  void openFeature(String title, String description, IconData icon) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _ProfileFeaturePage(
          title: title,
          description: description,
          icon: icon,
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
                  ),
                  const SizedBox(height: 14),
                  _StatsCard(
                    onFollowing: () => openFeature(
                      '我的关注',
                      '查看已关注的创作者和朋友',
                      Icons.person_add_alt_1_rounded,
                    ),
                    onFollowers: () =>
                        openFeature('我的粉丝', '查看关注你的社区成员', Icons.groups_rounded),
                    onLikes: () => openFeature(
                      '获赞记录',
                      '查看作品和动态获得的点赞',
                      Icons.favorite_rounded,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '我的内容',
                    children: [
                      _MenuItem(
                        key: const Key('profile-my-works'),
                        icon: Icons.play_circle_outline_rounded,
                        color: const Color(0xFF6658E8),
                        title: '我的作品',
                        subtitle: '12 个作品',
                        onTap: () => openContentTab(0),
                      ),
                      _MenuItem(
                        key: const Key('profile-favorites'),
                        icon: Icons.bookmark_outline_rounded,
                        color: const Color(0xFFFF8A42),
                        title: '收藏',
                        subtitle: '28 条收藏',
                        onTap: () => openContentTab(2),
                      ),
                      _MenuItem(
                        key: const Key('profile-communities'),
                        icon: Icons.forum_outlined,
                        color: const Color(0xFF28A887),
                        title: '我的社区',
                        subtitle: '已加入 6 个社区',
                        onTap: () => openFeature(
                          '我的社区',
                          '管理已加入的社区和群聊',
                          Icons.forum_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _SectionCard(
                    title: '创作者服务',
                    children: [
                      _MenuItem(
                        key: const Key('creator-center'),
                        icon: Icons.auto_awesome_rounded,
                        color: const Color(0xFF6A5CFF),
                        title: '创作者中心',
                        subtitle: '发布管理、粉丝数据和创作工具',
                        onTap: () => openFeature(
                          '创作者中心',
                          '今日播放 3,286，新增粉丝 46',
                          Icons.auto_awesome_rounded,
                        ),
                      ),
                      _MenuItem(
                        key: const Key('revenue-center'),
                        icon: Icons.trending_up_rounded,
                        color: const Color(0xFFFF6B6B),
                        title: '收益中心',
                        subtitle: '打赏、订阅和付费内容收益',
                        trailing: '¥1,268.50',
                        onTap: () => openFeature(
                          '收益中心',
                          '本月预估收益 ¥1,268.50',
                          Icons.trending_up_rounded,
                        ),
                      ),
                      _MenuItem(
                        key: const Key('wallet'),
                        icon: Icons.account_balance_wallet_outlined,
                        color: const Color(0xFFE2A323),
                        title: '钱包',
                        subtitle: '余额、充值、提现和交易记录',
                        trailing: '¥386.20',
                        onTap: () => openFeature(
                          '我的钱包',
                          '可用余额 ¥386.20',
                          Icons.account_balance_wallet_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _ProfileTabs(
                    key: tabSectionKey,
                    selected: selectedTab,
                    onSelected: selectTab,
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
  });

  final String nickname;
  final String avatarName;
  final String bio;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
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
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nickname,
                    key: const Key('profile-nickname'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '像素号：PX20260908',
                    style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 12),
                  ),
                  const SizedBox(height: 7),
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
        const SizedBox(height: 14),
        Text(
          bio,
          key: const Key('profile-bio'),
          style: const TextStyle(color: Colors.white, height: 1.45),
        ),
      ],
    ),
  );
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({
    required this.onFollowing,
    required this.onFollowers,
    required this.onLikes,
  });

  final VoidCallback onFollowing;
  final VoidCallback onFollowers;
  final VoidCallback onLikes;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          _StatItem(label: '关注', value: '24', onTap: onFollowing),
          const _VerticalDivider(),
          _StatItem(label: '粉丝', value: '1,286', onTap: onFollowers),
          const _VerticalDivider(),
          _StatItem(label: '获赞', value: '8.6万', onTap: onLikes),
        ],
      ),
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
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Color(0xFF7C7F89))),
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
    child: VerticalDivider(color: Color(0xFFE8E8ED)),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(15, 16, 15, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    super.key,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 22),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(
      subtitle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontSize: 12),
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              color: Color(0xFF5C50D6),
              fontWeight: FontWeight.w700,
            ),
          ),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFFA3A5AE)),
      ],
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
  });
  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Scaffold(
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
