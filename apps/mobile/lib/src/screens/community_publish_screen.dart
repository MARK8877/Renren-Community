import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../auth/auth_api.dart';
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
  static const mentionMembers = ['林木设计', '阿北摄影', '小鹿同学', 'Kevin Fan'];
  static const emojis = [
    '😀',
    '😂',
    '😍',
    '👍',
    '🎉',
    '🔥',
    '👏',
    '💡',
    '❤️',
    '🤝',
  ];
  static const imageAssets = [
    'assets/images/community-design-match.jpg',
    'assets/images/ai-video-workflow.png',
    'assets/images/community-design-lucky-king.jpg',
    'assets/images/community-design-collaboration.png',
  ];
  final contentController = TextEditingController();
  final groupNameController = TextEditingController();
  final ChatApi chatApi = ChatApi();
  final Set<String> selectedTopics = {'#社区交流'};
  final List<String> selectedImages = [];
  bool createGroup = false;
  bool showEmojiPanel = false;
  bool submitting = false;
  String? errorMessage;
  UserProfile? profile;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    if (!widget.session.signedIn) return;
    try {
      final value = await widget.session.getProfile();
      if (mounted) setState(() => profile = value);
    } on AuthException {
      // 接口不可用时仍可使用当前登录昵称发布。
    }
  }

  String get authorName => profile?.nickname ?? widget.session.nickname;

  String? get authorAvatarUrl {
    final value = profile?.avatarUrl.trim();
    return value == null || value.isEmpty ? null : value;
  }

  Future<void> openImagePicker() async {
    if (submitting) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Container(
          key: const Key('publish-image-picker'),
          height: 430,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9DBE4),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                '选择图片',
                style: TextStyle(
                  color: Color(0xFF1F2330),
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '从社区素材库选择，最多添加 9 张',
                style: TextStyle(color: Color(0xFF8B8D98), fontSize: 13),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  key: const Key('publish-image-options'),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  itemCount: imageAssets.length,
                  itemBuilder: (context, index) {
                    final asset = imageAssets[index];
                    final selected = selectedImages.contains(asset);
                    return InkWell(
                      key: Key('publish-image-option-$index'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        if (!selected && selectedImages.length < 9) {
                          setState(() => selectedImages.add(asset));
                        }
                        Navigator.pop(context);
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.asset(asset, fit: BoxFit.cover),
                          ),
                          if (selected)
                            const Align(
                              alignment: Alignment.topRight,
                              child: Padding(
                                padding: EdgeInsets.all(7),
                                child: Icon(
                                  CupertinoIcons.checkmark_circle_fill,
                                  color: Color(0xFF635BFF),
                                  size: 22,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openMentionPicker() async {
    if (submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          key: const Key('publish-mention-picker'),
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                '选择要 @ 的好友',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...mentionMembers.asMap().entries.map(
              (entry) => ListTile(
                key: Key('publish-mention-option-${entry.key}'),
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFE9E6FF),
                  child: Text(entry.value.characters.first),
                ),
                title: Text(entry.value),
                onTap: () {
                  insertAtCursor('@${entry.value} ');
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void insertAtCursor(String value) {
    final current = contentController.value;
    final start = current.selection.start < 0
        ? current.text.length
        : current.selection.start;
    final end = current.selection.end < 0
        ? current.text.length
        : current.selection.end;
    final text = current.text.replaceRange(start, end, value);
    contentController.value = current.copyWith(
      text: text,
      selection: TextSelection.collapsed(offset: start + value.length),
      composing: TextRange.empty,
    );
    setState(() {});
  }

  void toggleEmojiPanel() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => showEmojiPanel = !showEmojiPanel);
  }

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
        author: authorName,
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
    body: GestureDetector(
      key: const Key('publish-page-body'),
      behavior: HitTestBehavior.translucent,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
        if (showEmojiPanel) setState(() => showEmojiPanel = false);
      },
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                      key: const Key('publish-author-avatar'),
                      backgroundColor: const Color(0xFFE8E5FF),
                      foregroundImage: authorAvatarUrl == null
                          ? null
                          : NetworkImage(authorAvatarUrl!),
                      onForegroundImageError: authorAvatarUrl == null
                          ? null
                          : (_, _) {},
                      child: Text(authorName.characters.first),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          authorName,
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
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
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
                if (selectedImages.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '已添加 ${selectedImages.length}/9 张图片',
                      style: const TextStyle(
                        color: Color(0xFF777B8A),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.builder(
                    key: const Key('publish-selected-images'),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: selectedImages.length,
                    itemBuilder: (context, index) {
                      final asset = selectedImages[index];
                      return Stack(
                        key: Key('publish-selected-image-$index'),
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(asset, fit: BoxFit.cover),
                          ),
                          Positioned(
                            top: 5,
                            right: 5,
                            child: InkWell(
                              key: Key('publish-remove-image-$index'),
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(
                                () => selectedImages.removeAt(index),
                              ),
                              child: const CircleAvatar(
                                radius: 12,
                                backgroundColor: Color(0xB3000000),
                                child: Icon(
                                  CupertinoIcons.xmark,
                                  color: Colors.white,
                                  size: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _PublishTool(
                        key: const Key('publish-add-image'),
                        icon: CupertinoIcons.photo_on_rectangle,
                        label: '图片',
                        tint: const Color(0xFF3478D4),
                        onTap: openImagePicker,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PublishTool(
                        key: const Key('publish-mention'),
                        icon: CupertinoIcons.at,
                        label: '@好友',
                        tint: Color(0xFF7A62D4),
                        onTap: openMentionPicker,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PublishTool(
                        key: const Key('publish-emoji'),
                        icon: CupertinoIcons.smiley,
                        label: '表情',
                        tint: Color(0xFFE49A37),
                        onTap: toggleEmojiPanel,
                      ),
                    ),
                  ],
                ),
                if (showEmojiPanel)
                  Container(
                    key: const Key('publish-emoji-panel'),
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6F5FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: emojis
                          .map(
                            (emoji) => InkWell(
                              key: Key('publish-emoji-$emoji'),
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                insertAtCursor(emoji);
                                setState(() => showEmojiPanel = false);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 24),
                                ),
                              ),
                            ),
                          )
                          .toList(),
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
                      onTapOutside: (_) =>
                          FocusManager.instance.primaryFocus?.unfocus(),
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
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
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
                const Text(
                  '选择话题',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
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
    ),
  );
}

class _PublishTool extends StatelessWidget {
  const _PublishTool({
    super.key,
    required this.icon,
    required this.label,
    required this.tint,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: 58,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: tint, size: 21),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              color: tint,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    return onTap == null
        ? child
        : InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: child,
          );
  }
}
