import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../chat/chat_api.dart';
import 'group_chat_screen.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key, required this.session, this.chatApi});

  final AuthSession session;
  final ChatApi? chatApi;

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  static const avatarAssets = [
    'avatar/Avatar-1_1_11zon.png',
    'avatar/Avatar-2_2_11zon.png',
    'avatar/Avatar-3_3_11zon.png',
    'avatar/Avatar-4_4_11zon.png',
    'avatar/Avatar-5_5_11zon.png',
    'avatar/Avatar-6_6_11zon.png',
  ];

  final nameController = TextEditingController();
  final announcementController = TextEditingController();
  String selectedAvatar = avatarAssets.first;
  String joinMode = 'direct';
  bool memberInviteEnabled = true;
  bool submitting = false;

  ChatApi get api => widget.chatApi ?? ChatApi();

  @override
  void initState() {
    super.initState();
    nameController.addListener(refresh);
    announcementController.addListener(refresh);
  }

  @override
  void dispose() {
    nameController
      ..removeListener(refresh)
      ..dispose();
    announcementController
      ..removeListener(refresh)
      ..dispose();
    super.dispose();
  }

  void refresh() => setState(() {});

  bool get canSubmit {
    final length = nameController.text.trim().characters.length;
    final announcementLength = announcementController.text.characters.length;
    return length >= 2 &&
        length <= 30 &&
        announcementLength <= 500 &&
        !submitting;
  }

  Future<void> submit() async {
    if (!canSubmit) return;
    setState(() => submitting = true);
    try {
      final token = widget.session.accessToken;
      final group = token == null
          ? CreatedGroupData(
              id: 'local-group-${DateTime.now().microsecondsSinceEpoch}',
              name: nameController.text.trim(),
              memberCount: '1',
              avatarAssetKey: selectedAvatar,
              announcement: announcementController.text.trim(),
              joinMode: joinMode,
              memberInviteEnabled: memberInviteEnabled,
            )
          : await api.createGroup(
              token,
              nameController.text.trim(),
              avatarAssetKey: selectedAvatar,
              announcement: announcementController.text.trim(),
              joinMode: joinMode,
              memberInviteEnabled: memberInviteEnabled,
            );
      if (!mounted) return;
      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GroupChatScreen(
            groupName: group.name,
            memberCount: group.memberCount,
            currentUser: widget.session.nickname,
            conversationId: group.id,
            session: widget.session,
          ),
        ),
      );
    } on ChatApiException catch (error) {
      if (mounted) {
        setState(() => submitting = false);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('create-group-screen'),
    backgroundColor: const Color(0xFFF6F6F9),
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('发起群聊', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
      children: [
        _SectionCard(
          title: '群头像',
          child: Wrap(
            key: const Key('group-avatar-picker'),
            spacing: 12,
            runSpacing: 12,
            children: avatarAssets.map((asset) {
              final selected = asset == selectedAvatar;
              return InkWell(
                key: Key('group-avatar-$asset'),
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => selectedAvatar = asset),
                child: Container(
                  width: 54,
                  height: 54,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF6256E8)
                          : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/$asset',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFE6E7EE),
                        child: Icon(Icons.groups_rounded),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '群聊资料',
          child: Column(
            children: [
              TextField(
                key: const Key('group-name'),
                controller: nameController,
                maxLength: 30,
                decoration: const InputDecoration(
                  labelText: '群名称',
                  hintText: '例如：创作者共创群',
                  prefixIcon: Icon(Icons.groups_2_outlined),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('group-announcement'),
                controller: announcementController,
                maxLength: 500,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '群公告（可选）',
                  hintText: '告诉成员这里适合讨论什么',
                  prefixIcon: Icon(Icons.campaign_outlined),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: '入群设置',
          child: Column(
            key: const Key('group-join-mode'),
            children: [
              RadioListTile<String>(
                value: 'direct',
                groupValue: joinMode,
                onChanged: (value) => setState(() => joinMode = value!),
                title: const Text('允许直接加入'),
                subtitle: const Text('收到邀请后立即加入群聊'),
                contentPadding: EdgeInsets.zero,
              ),
              RadioListTile<String>(
                value: 'approval',
                groupValue: joinMode,
                onChanged: (value) => setState(() => joinMode = value!),
                title: const Text('需群主同意'),
                subtitle: const Text('群主确认后才加入群聊'),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                key: const Key('group-member-invite'),
                value: memberInviteEnabled,
                onChanged: (value) =>
                    setState(() => memberInviteEnabled = value),
                title: const Text('允许成员邀请好友'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          key: const Key('create-group-submit'),
          onPressed: canSubmit ? submit : null,
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('创建并进入群聊'),
        ),
      ],
    ),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}
