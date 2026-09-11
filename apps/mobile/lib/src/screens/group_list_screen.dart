import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../widgets/chat_avatar.dart';
import 'create_group_screen.dart';
import 'group_management_screen.dart';
import 'messages_screen.dart';

class GroupListScreen extends StatefulWidget {
  const GroupListScreen({
    super.key,
    required this.session,
    required this.groups,
    this.onGroupLeft,
  });

  final AuthSession session;
  final List<ConversationItem> groups;
  final ValueChanged<String>? onGroupLeft;

  @override
  State<GroupListScreen> createState() => _GroupListScreenState();
}

class _GroupListScreenState extends State<GroupListScreen> {
  late List<ConversationItem> groups;

  @override
  void initState() {
    super.initState();
    groups = List<ConversationItem>.of(widget.groups);
  }

  Future<void> openCreateGroup(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CreateGroupScreen(session: widget.session),
      ),
    );
  }

  Future<void> openManagement(
    BuildContext context,
    ConversationItem group,
  ) async {
    final leftGroup = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => GroupManagementScreen(
          session: widget.session,
          conversationId: group.id,
          groupName: group.name,
          memberCount: group.memberCount,
        ),
      ),
    );
    if (leftGroup == true && mounted) {
      setState(() => groups.removeWhere((item) => item.id == group.id));
      widget.onGroupLeft?.call(group.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sortedGroups = List<ConversationItem>.of(groups)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Scaffold(
      key: const Key('groups-list-screen'),
      backgroundColor: const Color(0xFFF6F6F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          '我的群组',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            key: const Key('group-list-create'),
            tooltip: '发起群聊',
            onPressed: () => openCreateGroup(context),
            icon: const Icon(Icons.group_add_outlined),
          ),
        ],
      ),
      body: sortedGroups.isEmpty
          ? Center(
              child: FilledButton.icon(
                key: const Key('group-list-empty-create'),
                onPressed: () => openCreateGroup(context),
                icon: const Icon(Icons.add_rounded),
                label: const Text('发起第一个群聊'),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: sortedGroups.length,
              itemBuilder: (context, index) {
                final group = sortedGroups[index];
                return Material(
                  color: Colors.white,
                  child: ListTile(
                    key: Key('group-list-${group.id}'),
                    contentPadding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
                    leading: ChatAvatar.group(
                      members: conversationAvatarMembers(group),
                      radius: 27,
                    ),
                    title: Text(
                      group.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${group.memberCount.isEmpty ? '1' : group.memberCount} 位成员',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          group.message.isEmpty ? '暂无新消息' : group.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.settings_outlined, size: 20),
                    onTap: () => openManagement(context, group),
                  ),
                );
              },
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 88),
            ),
    );
  }
}
