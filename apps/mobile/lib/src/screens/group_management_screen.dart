import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../chat/chat_api.dart';
import '../widgets/chat_avatar.dart';
import 'transfer_group_owner_screen.dart';

class GroupManagementScreen extends StatefulWidget {
  const GroupManagementScreen({
    super.key,
    required this.session,
    required this.conversationId,
    required this.groupName,
    required this.memberCount,
    this.chatApi,
  });

  final AuthSession session;
  final String conversationId;
  final String groupName;
  final String memberCount;
  final ChatApi? chatApi;

  @override
  State<GroupManagementScreen> createState() => _GroupManagementScreenState();
}

class _GroupManagementScreenState extends State<GroupManagementScreen> {
  final avatarAssets = const [
    'avatar/Avatar-1_1_11zon.png',
    'avatar/Avatar-2_2_11zon.png',
    'avatar/Avatar-3_3_11zon.png',
    'avatar/Avatar-4_4_11zon.png',
  ];
  late final TextEditingController announcementController;
  late final ChatApi api;
  GroupDetailsData? details;
  List<GroupMemberData> members = const [];
  List<JoinRequestData> joinRequests = const [];
  String selectedAvatar = 'avatar/Avatar-1_1_11zon.png';
  String joinMode = 'direct';
  bool memberInviteEnabled = true;
  bool loading = true;
  bool saving = false;
  bool leaving = false;

  String get role => details?.role ?? 'owner';
  bool get canManage => role == 'owner' || role == 'admin';
  bool get isOwner => role == 'owner';

  @override
  void initState() {
    super.initState();
    api = widget.chatApi ?? ChatApi();
    announcementController = TextEditingController();
    members = [
      GroupMemberData(
        userId: 1,
        nickname: widget.session.nickname,
        role: 'owner',
      ),
      const GroupMemberData(userId: 2, nickname: 'Luna', role: 'member'),
      const GroupMemberData(userId: 3, nickname: '小宇', role: 'member'),
    ];
    load();
  }

  @override
  void dispose() {
    announcementController.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final token = widget.session.accessToken;
    if (token != null) {
      try {
        final result = await Future.wait([
          api.groupDetails(token, widget.conversationId),
          api.groupMembers(token, widget.conversationId),
        ]);
        if (!mounted) return;
        final loadedDetails = result[0] as GroupDetailsData;
        final loadedMembers = result[1] as List<GroupMemberData>;
        final loadedRequests = loadedDetails.role == 'owner'
            ? await api.joinRequests(token, widget.conversationId)
            : const <JoinRequestData>[];
        setState(() {
          details = loadedDetails;
          members = loadedMembers;
          joinRequests = loadedRequests;
          announcementController.text = loadedDetails.announcement;
          selectedAvatar = loadedDetails.avatarAssetKey.isEmpty
              ? selectedAvatar
              : loadedDetails.avatarAssetKey;
          joinMode = loadedDetails.joinMode;
          memberInviteEnabled = loadedDetails.memberInviteEnabled;
          loading = false;
        });
        return;
      } on ChatApiException catch (error) {
        if (mounted) showMessage(error.message);
      } catch (_) {
        // Response decoding can fail before ChatApi wraps the error. Keep the
        // group page usable instead of allowing an async exception to crash
        // the route when a stale or malformed group payload is returned.
        if (mounted) showMessage('群组数据加载失败，请稍后重试');
      }
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> saveProfile() async {
    if (!canManage || saving) return;
    setState(() => saving = true);
    final token = widget.session.accessToken;
    try {
      if (token != null) {
        final updated = await api.updateGroup(
          token,
          widget.conversationId,
          avatarAssetKey: selectedAvatar,
          announcement: announcementController.text.trim(),
          joinMode: joinMode,
          memberInviteEnabled: memberInviteEnabled,
        );
        if (!mounted) return;
        setState(() => details = updated);
      }
      if (mounted) showMessage('群资料已保存');
    } on ChatApiException catch (error) {
      if (mounted) showMessage(error.message);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> changeRole(GroupMemberData member) async {
    if (!isOwner) return;
    final nextRole = member.role == 'admin' ? 'member' : 'admin';
    final token = widget.session.accessToken;
    try {
      if (token != null) {
        await api.setMemberRole(
          token,
          widget.conversationId,
          member.userId,
          nextRole,
        );
      }
      if (!mounted) return;
      setState(() {
        members = members
            .map(
              (item) => item.userId == member.userId
                  ? GroupMemberData(
                      userId: item.userId,
                      nickname: item.nickname,
                      role: nextRole,
                      mutedUntil: item.mutedUntil,
                    )
                  : item,
            )
            .toList();
      });
      showMessage(nextRole == 'admin' ? '已设为管理员' : '已取消管理员');
    } on ChatApiException catch (error) {
      if (mounted) showMessage(error.message);
    }
  }

  Future<void> muteMember(GroupMemberData member) async {
    if (!canManage || member.role != 'member') return;
    final until = DateTime.now().add(const Duration(hours: 1));
    final token = widget.session.accessToken;
    try {
      if (token != null) {
        await api.setMemberMute(
          token,
          widget.conversationId,
          member.userId,
          until,
        );
      }
      if (mounted) showMessage('已禁言 1 小时');
    } on ChatApiException catch (error) {
      if (mounted) showMessage(error.message);
    }
  }

  Future<void> removeMember(GroupMemberData member) async {
    if (!canManage || member.role != 'member') return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('移除${member.nickname}？'),
        content: const Text('移除后对方将无法继续查看和发送群消息。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('移除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final token = widget.session.accessToken;
    try {
      if (token != null) {
        await api.removeMember(token, widget.conversationId, member.userId);
      }
      if (mounted) {
        setState(
          () => members = members
              .where((item) => item.userId != member.userId)
              .toList(),
        );
        showMessage('已移除成员');
      }
    } on ChatApiException catch (error) {
      if (mounted) showMessage(error.message);
    }
  }

  Future<void> inviteMember() async {
    if (!canManage) return;
    final controller = TextEditingController();
    final userId = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('邀请成员'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '用户 ID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text.trim())),
            child: const Text('邀请'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (userId == null || userId <= 0) return;
    final token = widget.session.accessToken;
    try {
      if (token != null) {
        await api.inviteMember(token, widget.conversationId, userId);
      }
      if (mounted) {
        showMessage(joinMode == 'approval' ? '邀请已提交，等待群主确认' : '成员邀请成功');
      }
    } on ChatApiException catch (error) {
      if (mounted) showMessage(error.message);
    }
  }

  Future<void> resolveRequest(JoinRequestData request, bool accept) async {
    final token = widget.session.accessToken;
    if (token != null) {
      try {
        await api.resolveJoinRequest(
          token,
          widget.conversationId,
          request.id,
          accept,
        );
      } on ChatApiException catch (error) {
        if (mounted) showMessage(error.message);
        return;
      }
    }
    if (mounted) {
      setState(
        () => joinRequests = joinRequests
            .where((item) => item.id != request.id)
            .toList(),
      );
      showMessage(accept ? '已同意入群申请' : '已拒绝入群申请');
    }
  }

  Future<void> leaveGroup() async {
    if (leaving) return;
    if (isOwner) {
      showMessage('群主不能直接退出，请先转让群主');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('leave-group-dialog'),
        title: const Text('退出群聊？'),
        content: const Text('退出后将不再接收群消息，之后需要重新申请加入。'),
        actions: [
          TextButton(
            key: const Key('cancel-leave-group'),
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('confirm-leave-group'),
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE5484D),
            ),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => leaving = true);
    try {
      final token = widget.session.accessToken;
      if (token != null) {
        await api.leaveGroup(token, widget.conversationId);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ChatApiException catch (error) {
      if (mounted) showMessage(error.message);
    } finally {
      if (mounted) setState(() => leaving = false);
    }
  }

  void showMessage(String message) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        key: Key('group-management-screen'),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      key: const Key('group-management-screen'),
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: const Text(
          '群聊设置',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (canManage)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: TextButton(
                key: const Key('management-save-profile'),
                onPressed: saving ? null : saveProfile,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6256E8),
                  disabledForegroundColor: const Color(0xFF9EA1AD),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                child: Text(saving ? '保存中' : '保存'),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          _ManagementCard(
            key: const Key('group-management-profile-hero'),
            title: '',
            child: Row(
              children: [
                ChatAvatar.group(
                  members: const ['Kevin AI', 'Luna', '小宇', '阿杰'],
                  radius: 36,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.groupName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2329),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${widget.memberCount} 位成员',
                        style: const TextStyle(color: Color(0xFF858B95)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        announcementController.text.trim().isEmpty
                            ? '设置群公告，让成员快速了解群聊主题'
                            : announcementController.text.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF5D6470),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ManagementCard(
            key: const Key('group-management-section-profile'),
            title: '群资料',
            subtitle: '头像和公告会展示给所有群成员',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  key: const Key('management-avatar-picker'),
                  spacing: 10,
                  runSpacing: 10,
                  children: avatarAssets.map((asset) {
                    final selected = asset == selectedAvatar;
                    return InkWell(
                      key: Key('management-avatar-$asset'),
                      onTap: canManage
                          ? () => setState(() => selectedAvatar = asset)
                          : null,
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF6256E8)
                                : const Color(0xFFE7E8ED),
                            width: selected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.asset(
                            'assets/$asset',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                TextField(
                  key: const Key('management-announcement'),
                  controller: announcementController,
                  enabled: canManage,
                  maxLength: 500,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: '群公告',
                    hintText: '告诉成员这个群聊主要讨论什么',
                    filled: true,
                    fillColor: const Color(0xFFF7F8FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ManagementCard(
            key: const Key('group-management-section-permissions'),
            title: '群聊权限',
            subtitle: '控制成员如何加入和邀请好友',
            child: Column(
              children: [
                RadioListTile<String>(
                  value: 'direct',
                  groupValue: joinMode,
                  onChanged: isOwner
                      ? (value) => setState(() => joinMode = value!)
                      : null,
                  title: const Text('允许直接加入'),
                  subtitle: const Text('成员点击群链接后可直接进入'),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                RadioListTile<String>(
                  value: 'approval',
                  groupValue: joinMode,
                  onChanged: isOwner
                      ? (value) => setState(() => joinMode = value!)
                      : null,
                  title: const Text('需群主同意'),
                  subtitle: const Text('新成员申请后由群主审核'),
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: 1),
                SwitchListTile(
                  key: const Key('management-member-invite'),
                  value: memberInviteEnabled,
                  onChanged: isOwner
                      ? (value) => setState(() => memberInviteEnabled = value)
                      : null,
                  title: const Text('允许成员邀请好友'),
                  subtitle: const Text('关闭后仅群主和管理员可以邀请'),
                  contentPadding: EdgeInsets.zero,
                ),
                if (isOwner) ...[
                  const Divider(height: 1),
                  ListTile(
                    key: const Key('transfer-owner-entry'),
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFF1D6),
                      child: Icon(
                        Icons.swap_horiz_rounded,
                        color: Color(0xFFB7791F),
                      ),
                    ),
                    title: const Text('转让群主'),
                    subtitle: const Text('将群主权限交给其他群成员'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => TransferGroupOwnerScreen(
                            session: widget.session,
                            conversationId: widget.conversationId,
                            members: members,
                            chatApi: api,
                          ),
                        ),
                      );
                      if (changed == true && mounted) await load();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ManagementCard(
            key: const Key('group-management-section-members'),
            title: '群成员',
            subtitle: '${members.length} 位成员，点击右侧按钮进行管理',
            child: Column(
              key: const Key('management-member-list'),
              children: [
                ...members.map((member) {
                  final protectedMember = member.role != 'member';
                  return ListTile(
                    key: Key('management-member-${member.userId}'),
                    contentPadding: EdgeInsets.zero,
                    leading: ChatAvatar.person(
                      name: member.nickname,
                      radius: 20,
                    ),
                    title: Text(member.nickname),
                    subtitle: Text(
                      member.role == 'owner'
                          ? '群主'
                          : member.role == 'admin'
                          ? '管理员'
                          : member.mutedUntil != null
                          ? '已禁言'
                          : '成员',
                    ),
                    trailing: canManage && !protectedMember
                        ? PopupMenuButton<String>(
                            key: Key('member-actions-${member.userId}'),
                            onSelected: (action) {
                              if (action == 'mute') muteMember(member);
                              if (action == 'remove') removeMember(member);
                              if (action == 'admin') changeRole(member);
                            },
                            itemBuilder: (_) => [
                              if (isOwner)
                                const PopupMenuItem(
                                  value: 'admin',
                                  child: Text('设为管理员'),
                                ),
                              const PopupMenuItem(
                                value: 'mute',
                                child: Text('禁言 1 小时'),
                              ),
                              const PopupMenuItem(
                                value: 'remove',
                                child: Text('移除成员'),
                              ),
                            ],
                          )
                        : null,
                  );
                }),
                if (canManage)
                  ListTile(
                    key: const Key('management-invite-member'),
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE9E7FF),
                      child: Icon(
                        Icons.person_add_alt_1_rounded,
                        color: Color(0xFF6256E8),
                      ),
                    ),
                    title: const Text('邀请新成员'),
                    subtitle: const Text('通过用户 ID 邀请加入群聊'),
                    onTap: inviteMember,
                  ),
              ],
            ),
          ),
          if (isOwner && joinRequests.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ManagementCard(
              title: '入群申请',
              subtitle: '审核新成员的加入请求',
              child: Column(
                key: const Key('management-join-requests'),
                children: joinRequests
                    .map(
                      (request) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ChatAvatar.person(
                          name: request.applicantName,
                          radius: 20,
                        ),
                        title: Text(request.applicantName),
                        subtitle: const Text('申请加入群聊'),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: '同意',
                              onPressed: () => resolveRequest(request, true),
                              icon: const Icon(Icons.check_circle_outline),
                            ),
                            IconButton(
                              tooltip: '拒绝',
                              onPressed: () => resolveRequest(request, false),
                              icon: const Icon(Icons.cancel_outlined),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ListTile(
              key: const Key('leave-group'),
              tileColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              leading: const Icon(
                Icons.logout_rounded,
                color: Color(0xFFE5484D),
              ),
              title: const Text(
                '退出群聊',
                style: TextStyle(
                  color: Color(0xFFE5484D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                isOwner ? '群主请先转让群主后再退出' : '退出后将不再接收群消息',
                style: const TextStyle(color: Color(0xFF8A9099)),
              ),
              trailing: leaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right_rounded),
              onTap: leaveGroup,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManagementCard extends StatelessWidget {
  const _ManagementCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            if (title.isNotEmpty) const SizedBox(height: 3),
            Text(
              subtitle!,
              style: const TextStyle(color: Color(0xFF8A9099), fontSize: 12),
            ),
          ],
          if (title.isNotEmpty || subtitle != null) const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}
