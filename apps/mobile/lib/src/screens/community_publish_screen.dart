import 'package:flutter/material.dart';

import '../auth/auth_session.dart';
import '../chat/chat_api.dart';
import '../community/community_post.dart';

class CommunityPublishScreen extends StatefulWidget {
  const CommunityPublishScreen({super.key, required this.session});

  final AuthSession session;

  @override
  State<CommunityPublishScreen> createState() => _CommunityPublishScreenState();
}

class _CommunityPublishScreenState extends State<CommunityPublishScreen> {
  static const topics = ['#社区交流', '#产品思考', '#创作日常', '#经验分享'];
  final contentController = TextEditingController();
  final groupNameController = TextEditingController();
  final ChatApi chatApi = ChatApi();
  final Set<String> selectedTopics = {'#社区交流'};
  bool createGroup = false;
  bool submitting = false;
  String? errorMessage;

  @override
  void dispose() {
    contentController.dispose();
    groupNameController.dispose();
    super.dispose();
  }

  bool get canPublish {
    final groupNameLength = groupNameController.text.trim().characters.length;
    return contentController.text.trim().isNotEmpty &&
        (!createGroup || (groupNameLength >= 2 && groupNameLength <= 30)) &&
        !submitting;
  }

  Future<void> publish() async {
    final content = contentController.text.trim();
    if (content.isEmpty) return;
    setState(() {
      submitting = true;
      errorMessage = null;
    });
    String? groupId;
    String? groupName;
    String? groupMemberCount;
    if (createGroup) {
      groupName = groupNameController.text.trim();
      final token = widget.session.accessToken;
      if (token != null) {
        try {
          final group = await chatApi.createGroup(token, groupName);
          groupId = group.id;
          groupName = group.name;
          groupMemberCount = group.memberCount;
        } on ChatApiException catch (error) {
          if (!mounted) return;
          setState(() {
            submitting = false;
            errorMessage = error.message;
          });
          return;
        }
      } else {
        groupId = 'local-group-${DateTime.now().microsecondsSinceEpoch}';
        groupMemberCount = '1';
      }
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      CommunityPost(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        author: widget.session.nickname,
        content: content,
        tags: selectedTopics.toList(),
        createdAt: DateTime.now(),
        groupId: groupId,
        groupName: groupName,
        groupMemberCount: groupMemberCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('community-publish-screen'),
    backgroundColor: const Color(0xFFF7F7FA),
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('发布动态'),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 10),
          child: FilledButton(
            key: const Key('publish-submit'),
            onPressed: canPublish ? publish : null,
            child: const Text('发布'),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE8E5FF),
                    child: Text(widget.session.nickname.characters.first),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.session.nickname,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const Text(
                        '公开发布到社区',
                        style: TextStyle(
                          color: Color(0xFF8B8D98),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('publish-content'),
                controller: contentController,
                onChanged: (_) => setState(() {}),
                autofocus: true,
                minLines: 7,
                maxLines: 14,
                maxLength: 1000,
                decoration: const InputDecoration(
                  hintText: '分享你的想法、经验或社区新鲜事…',
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('publish-create-group'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    '同时创建群聊',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('动态发布后，成员可从动态直接加入群聊'),
                  value: createGroup,
                  onChanged: submitting
                      ? null
                      : (value) {
                          setState(() {
                            createGroup = value;
                            errorMessage = null;
                          });
                        },
                ),
                if (createGroup)
                  TextField(
                    key: const Key('publish-group-name'),
                    controller: groupNameController,
                    onChanged: (_) => setState(() {}),
                    maxLength: 30,
                    enabled: !submitting,
                    decoration: const InputDecoration(
                      labelText: '群名称',
                      hintText: '请输入 2 至 30 个字符',
                      prefixIcon: Icon(Icons.groups_2_outlined),
                    ),
                  ),
                if (errorMessage != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        errorMessage!,
                        key: const Key('publish-group-error'),
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('选择话题', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topics
                    .map(
                      (topic) => FilterChip(
                        key: Key('publish-topic-$topic'),
                        label: Text(topic),
                        selected: selectedTopics.contains(topic),
                        onSelected: (selected) => setState(
                          () => selected
                              ? selectedTopics.add(topic)
                              : selectedTopics.remove(topic),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(8, 18, 8, 0),
          child: Text(
            '请遵守社区规则，保持友善交流。',
            textAlign: TextAlign.center,
            style: TextStyle(color: Color(0xFF9698A2), fontSize: 12),
          ),
        ),
      ],
    ),
  );
}
