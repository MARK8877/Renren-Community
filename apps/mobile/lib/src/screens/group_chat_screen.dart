import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_session.dart';
import '../chat/chat_api.dart';
import '../widgets/chat_avatar.dart';
import 'group_management_screen.dart';

enum ChatMessageType { text, image, video, content }

enum ChatSendStatus { sending, sent, failed }

const _groupAvatarMembers = ['Kevin AI', 'Luna', '小宇', '阿杰'];

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.time,
    this.type = ChatMessageType.text,
    this.isMine = false,
    this.replyTo,
    this.replyToMessageId,
    this.status = ChatSendStatus.sent,
    this.recalled = false,
  });

  String id;
  final String sender;
  final String text;
  String time;
  final ChatMessageType type;
  final bool isMine;
  final String? replyTo;
  final int? replyToMessageId;
  ChatSendStatus status;
  bool recalled;
}

class GroupChatScreen extends StatefulWidget {
  const GroupChatScreen({
    super.key,
    required this.groupName,
    required this.memberCount,
    required this.currentUser,
    this.conversationId,
    this.session,
    this.mutedUntil,
  });

  final String groupName;
  final String memberCount;
  final String currentUser;
  final String? conversationId;
  final AuthSession? session;
  final String? mutedUntil;

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final ChatApi chatApi = ChatApi();
  final input = TextEditingController();
  final scrollController = ScrollController();
  final focusNode = FocusNode();
  bool showEmojiPanel = false;
  bool loadingHistory = false;
  ChatMessage? replyingTo;
  late List<ChatMessage> messages;

  @override
  void initState() {
    super.initState();
    messages = [
      ChatMessage(
        id: '1',
        sender: 'Kevin AI',
        text: '欢迎大家加入！这里可以交流 AI 视频创作流程。',
        time: '10:18',
      ),
      ChatMessage(
        id: '2',
        sender: '小宇',
        text: '刚试了视频里的方法，生成效率提升很多。',
        time: '10:22',
      ),
      ChatMessage(
        id: '3',
        sender: 'Luna',
        text: 'AI 视频工作流示例',
        time: '10:26',
        type: ChatMessageType.image,
      ),
      ChatMessage(
        id: '4',
        sender: 'Kevin AI',
        text: '用 AI 制作短视频，我最常用的 5 个步骤',
        time: '10:31',
        type: ChatMessageType.content,
      ),
      ChatMessage(
        id: 'failed-demo',
        sender: widget.currentUser,
        text: '有人整理过完整的工具清单吗？',
        time: '10:33',
        isMine: true,
        status: ChatSendStatus.failed,
      ),
    ];
    if (widget.session?.signedIn == true) {
      unawaited(loadRemoteMessages());
    }
  }

  String get resolvedConversationId =>
      widget.conversationId ??
      switch (widget.groupName) {
        '产品设计交流社区' => 'group-product',
        '活动运营共创群' => 'group-event',
        '创作者交流群' => 'group-creators',
        _ => 'group-ai',
      };

  Future<void> loadRemoteMessages() async {
    final token = widget.session?.accessToken;
    if (token == null) return;
    try {
      final remote = await chatApi.messages(token, resolvedConversationId);
      if (!mounted) return;
      final byId = {for (final item in remote) item.id: item};
      setState(() {
        messages = remote
            .map(
              (item) => ChatMessage(
                id: item.id.toString(),
                sender: item.senderName,
                text: item.content,
                time: formatMessageTime(item.createdAt),
                type: chatMessageType(item.type),
                isMine:
                    item.senderId > 0 && item.senderName == widget.currentUser,
                replyTo: item.replyToMessageId == 0
                    ? null
                    : byId[item.replyToMessageId]?.content,
                recalled: item.recalled,
              ),
            )
            .toList();
      });
      if (remote.isNotEmpty) {
        await chatApi.markRead(token, resolvedConversationId, remote.last.id);
      }
      scrollToBottom();
    } on ChatApiException catch (error) {
      if (mounted) showMessage(error.message);
    }
  }

  ChatMessageType chatMessageType(String value) => switch (value) {
    'image' => ChatMessageType.image,
    'video' => ChatMessageType.video,
    'content' => ChatMessageType.content,
    _ => ChatMessageType.text,
  };

  String formatMessageTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    input.dispose();
    scrollController.dispose();
    focusNode.dispose();
    super.dispose();
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> loadHistory() async {
    if (loadingHistory) return;
    final token = widget.session?.accessToken;
    final firstID = messages.isEmpty ? null : int.tryParse(messages.first.id);
    if (token != null && firstID != null) {
      setState(() => loadingHistory = true);
      try {
        final remote = await chatApi.messages(
          token,
          resolvedConversationId,
          beforeId: firstID,
        );
        if (!mounted) return;
        setState(() {
          messages.insertAll(
            0,
            remote.map(
              (item) => ChatMessage(
                id: item.id.toString(),
                sender: item.senderName,
                text: item.content,
                time: formatMessageTime(item.createdAt),
                type: chatMessageType(item.type),
                isMine:
                    item.senderId > 0 && item.senderName == widget.currentUser,
                recalled: item.recalled,
              ),
            ),
          );
          loadingHistory = false;
        });
      } on ChatApiException catch (error) {
        if (!mounted) return;
        setState(() => loadingHistory = false);
        showMessage(error.message);
      }
      return;
    }
    setState(() => loadingHistory = true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() {
      messages.insertAll(0, [
        ChatMessage(
          id: 'history-1',
          sender: '群助手',
          text: '请友善交流，不发布广告或违规内容。',
          time: '昨天 21:08',
        ),
        ChatMessage(
          id: 'history-2',
          sender: '阿杰',
          text: '大家常用哪些剪辑工具？',
          time: '昨天 21:12',
        ),
      ]);
      loadingHistory = false;
    });
  }

  void insertMention(String member) {
    final mention = '@$member ';
    input.text = '${input.text}$mention';
    input.selection = TextSelection.collapsed(offset: input.text.length);
    focusNode.requestFocus();
  }

  void sendText() {
    if (widget.mutedUntil != null) return;
    final value = input.text.trim();
    if (value.isEmpty) return;
    final message = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: widget.currentUser,
      text: value,
      time: '刚刚',
      isMine: true,
      replyTo: replyingTo == null
          ? null
          : '${replyingTo!.sender}：${replyingTo!.text}',
      replyToMessageId: int.tryParse(replyingTo?.id ?? ''),
      status: ChatSendStatus.sending,
    );
    setState(() {
      messages.add(message);
      input.clear();
      replyingTo = null;
      showEmojiPanel = false;
    });
    scrollToBottom();
    unawaited(_completeSend(message));
  }

  void sendAttachment(ChatMessageType type, String text) {
    final message = ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: widget.currentUser,
      text: text,
      time: '刚刚',
      type: type,
      isMine: true,
      status: ChatSendStatus.sending,
    );
    setState(() => messages.add(message));
    Navigator.pop(context);
    scrollToBottom();
    unawaited(_completeSend(message));
  }

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _completeSend(ChatMessage message) async {
    final token = widget.session?.accessToken;
    if (token != null) {
      try {
        final saved = await chatApi.sendMessage(
          token,
          resolvedConversationId,
          type: message.type.name,
          content: message.text,
          clientMessageId: message.id,
          replyToMessageId: message.replyToMessageId,
        );
        if (!mounted || !messages.contains(message)) return;
        setState(() {
          message.id = saved.id.toString();
          message.time = formatMessageTime(saved.createdAt);
          message.status = ChatSendStatus.sent;
        });
        return;
      } on ChatApiException {
        if (!mounted || !messages.contains(message)) return;
        setState(() => message.status = ChatSendStatus.failed);
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted || !messages.contains(message)) return;
    setState(() => message.status = ChatSendStatus.sent);
  }

  void retry(ChatMessage message) {
    setState(() => message.status = ChatSendStatus.sending);
    unawaited(_completeSend(message));
  }

  Future<void> showMessageActions(ChatMessage message) async {
    if (message.recalled) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.reply_rounded),
              title: const Text('回复'),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => replyingTo = message);
                focusNode.requestFocus();
              },
            ),
            ListTile(
              leading: const Icon(Icons.alternate_email_rounded),
              title: Text('@${message.sender}'),
              onTap: () {
                Navigator.pop(sheetContext);
                insertMention(message.sender);
              },
            ),
            if (message.type == ChatMessageType.text)
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('复制'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: message.text));
                  if (!sheetContext.mounted) return;
                  Navigator.pop(sheetContext);
                  showMessage('消息已复制');
                },
              ),
            if (message.isMine)
              ListTile(
                leading: const Icon(Icons.undo_rounded),
                title: const Text('撤回'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  setState(() => message.recalled = true);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('举报'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showMessage('举报已提交');
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> showMembers() async {
    const members = ['Kevin AI（群主）', 'Luna（管理员）', '小宇', '阿杰'];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                '选择要 @ 的成员',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            ...members.map(
              (member) => ListTile(
                leading: ChatAvatar.person(
                  name: member.split('（').first,
                  radius: 20,
                ),
                title: Text(member),
                onTap: () {
                  Navigator.pop(context);
                  insertMention(member.split('（').first);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showAttachments() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AttachmentButton(
                key: const Key('send-image'),
                icon: Icons.image_outlined,
                label: '图片',
                onTap: () => sendAttachment(ChatMessageType.image, '我分享了一张图片'),
              ),
              _AttachmentButton(
                key: const Key('send-video'),
                icon: Icons.videocam_outlined,
                label: '视频',
                onTap: () => sendAttachment(ChatMessageType.video, '我分享了一段视频'),
              ),
              _AttachmentButton(
                key: const Key('send-content'),
                icon: Icons.article_outlined,
                label: '内容',
                onTap: () => sendAttachment(
                  ChatMessageType.content,
                  '社区产品如何把内容浏览变成真实关系？',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> openGroupInfo() async {
    final exited = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => GroupInfoScreen(
          groupName: widget.groupName,
          memberCount: widget.memberCount,
          conversationId: widget.conversationId,
          session: widget.session,
        ),
      ),
    );
    if (exited == true && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        titleSpacing: 0,
        title: InkWell(
          key: const Key('group-info-entry'),
          onTap: openGroupInfo,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.groupName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${widget.memberCount}人 · 在线 326',
                style: const TextStyle(fontSize: 11, color: Color(0xFF8B8D98)),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: '群成员',
            onPressed: showMembers,
            icon: const Icon(Icons.group_outlined),
          ),
          IconButton(
            tooltip: '群资料',
            onPressed: openGroupInfo,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Material(
            color: const Color(0xFFFFF7DF),
            child: ListTile(
              dense: true,
              leading: const Icon(
                Icons.campaign_outlined,
                color: Color(0xFFE09B25),
              ),
              title: const Text('群公告：请遵守群规，友善交流，共同成长。'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => showMessage('已查看完整群公告'),
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: const Key('message-list'),
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              itemCount: messages.length + 1 + (messages.length >= 2 ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Center(
                    child: TextButton.icon(
                      key: const Key('load-history'),
                      onPressed: loadingHistory ? null : loadHistory,
                      icon: loadingHistory
                          ? const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.history_rounded, size: 18),
                      label: Text(loadingHistory ? '加载中…' : '加载更早消息'),
                    ),
                  );
                }
                final showUnreadDivider = messages.length >= 2;
                if (showUnreadDivider && index == 3) {
                  return const _UnreadDivider();
                }
                final messageIndex = showUnreadDivider && index > 3
                    ? index - 2
                    : index - 1;
                final message = messages[messageIndex];
                return _MessageBubble(
                  key: Key('message-${message.id}'),
                  message: message,
                  onLongPress: () => showMessageActions(message),
                  onRetry: () => retry(message),
                );
              },
            ),
          ),
          if (replyingTo != null)
            Container(
              key: const Key('reply-preview'),
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '回复 ${replyingTo!.sender}：${replyingTo!.text}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF72747F),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => replyingTo = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          if (widget.mutedUntil != null)
            Container(
              key: const Key('muted-notice'),
              width: double.infinity,
              color: const Color(0xFFFFF1F1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(
                '你已被禁言，解除时间：${widget.mutedUntil}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ),
          _Composer(
            input: input,
            focusNode: focusNode,
            enabled: widget.mutedUntil == null,
            onSend: sendText,
            onMention: showMembers,
            onEmoji: () {
              setState(() => showEmojiPanel = !showEmojiPanel);
              if (showEmojiPanel) focusNode.unfocus();
            },
            onAdd: showAttachments,
          ),
          if (showEmojiPanel)
            _EmojiPanel(
              onSelected: (emoji) {
                input.text = '${input.text}$emoji';
                input.selection = TextSelection.collapsed(
                  offset: input.text.length,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            '以下是未读消息',
            style: TextStyle(fontSize: 12, color: Color(0xFF8A7BF0)),
          ),
        ),
        Expanded(child: Divider()),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.onLongPress,
    required this.onRetry,
  });

  final ChatMessage message;
  final VoidCallback onLongPress;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (message.recalled) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Center(
          child: Text(
            message.isMine ? '你撤回了一条消息' : '${message.sender} 撤回了一条消息',
            style: const TextStyle(fontSize: 12, color: Color(0xFF9A9CA5)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: message.isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isMine) ...[
            ChatAvatar.person(name: message.sender, radius: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!message.isMine)
                  Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 4),
                    child: Text(
                      message.sender,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF838590),
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: onLongPress,
                  child: _MessageContent(message: message),
                ),
                const SizedBox(height: 3),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.time,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFFA1A3AB),
                      ),
                    ),
                    if (message.isMine) ...[
                      const SizedBox(width: 4),
                      if (message.status == ChatSendStatus.sending)
                        const SizedBox.square(
                          dimension: 11,
                          child: CircularProgressIndicator(strokeWidth: 1.4),
                        )
                      else if (message.status == ChatSendStatus.failed)
                        InkWell(
                          onTap: onRetry,
                          child: const Icon(
                            Icons.error_rounded,
                            size: 16,
                            color: Colors.red,
                          ),
                        )
                      else
                        const Icon(
                          Icons.done_all_rounded,
                          size: 14,
                          color: Color(0xFF7769EA),
                        ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (message.isMine) ...[
            const SizedBox(width: 8),
            ChatAvatar.person(
              name: message.sender,
              radius: 18,
              emphasized: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final color = message.isMine ? const Color(0xFF6A5CFF) : Colors.white;
    final textColor = message.isMine ? Colors.white : const Color(0xFF292A32);
    return Container(
      constraints: const BoxConstraints(maxWidth: 270),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: message.isMine
                    ? Colors.white.withValues(alpha: 0.18)
                    : const Color(0xFFF1F1F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message.replyTo!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: textColor.withValues(alpha: 0.8),
                ),
              ),
            ),
          if (message.type == ChatMessageType.image)
            _MediaPreview(icon: Icons.image_rounded, label: message.text)
          else if (message.type == ChatMessageType.video)
            _MediaPreview(
              icon: Icons.play_circle_fill_rounded,
              label: message.text,
            )
          else if (message.type == ChatMessageType.content)
            _ContentPreview(title: message.text)
          else
            Text(message.text, style: TextStyle(color: textColor, height: 1.4)),
        ],
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 190,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 110,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF373C52), Color(0xFF7669CE)],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Icon(icon, size: 40, color: Colors.white)),
        ),
        const SizedBox(height: 7),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    ),
  );
}

class _ContentPreview extends StatelessWidget {
  const _ContentPreview({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: Row(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFE7E3FF),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF6256E8)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.input,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
    required this.onMention,
    required this.onEmoji,
    required this.onAdd,
  });

  final TextEditingController input;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback onMention;
  final VoidCallback onEmoji;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            key: const Key('mention-button'),
            tooltip: '@成员',
            onPressed: enabled ? onMention : null,
            icon: const Icon(Icons.alternate_email_rounded),
          ),
          Expanded(
            child: TextField(
              key: const Key('chat-input'),
              controller: input,
              focusNode: focusNode,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: '发送消息…',
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF3F3F7),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
          IconButton(
            key: const Key('emoji-button'),
            tooltip: '表情',
            onPressed: enabled ? onEmoji : null,
            icon: const Icon(Icons.sentiment_satisfied_alt_rounded),
          ),
          IconButton(
            key: const Key('attachment-button'),
            tooltip: '添加',
            onPressed: enabled ? onAdd : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
          ),
          IconButton(
            key: const Key('send-button'),
            tooltip: '发送',
            onPressed: enabled ? onSend : null,
            icon: const Icon(Icons.send_rounded, color: Color(0xFF6256E8)),
          ),
        ],
      ),
    ),
  );
}

class _EmojiPanel extends StatelessWidget {
  const _EmojiPanel({required this.onSelected});
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const emojis = ['😀', '😂', '😍', '👍', '🎉', '🔥', '👏', '💡', '❤️', '🤝'];
    return Container(
      key: const Key('emoji-panel'),
      height: 105,
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: emojis
            .map(
              (emoji) => InkWell(
                key: Key('emoji-$emoji'),
                onTap: () => onSelected(emoji),
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(emoji, style: const TextStyle(fontSize: 24)),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _AttachmentButton extends StatelessWidget {
  const _AttachmentButton({
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
    borderRadius: BorderRadius.circular(14),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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

class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({
    super.key,
    required this.groupName,
    required this.memberCount,
    this.conversationId,
    this.session,
  });

  final String groupName;
  final String memberCount;
  final String? conversationId;
  final AuthSession? session;

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  bool notificationsEnabled = true;

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    const members = ['Kevin AI', 'Luna', '小宇', '阿杰'];
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F8),
      appBar: AppBar(title: const Text('群资料')),
      body: ListView(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                const ChatAvatar.group(
                  members: _groupAvatarMembers,
                  radius: 38,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.groupName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${widget.memberCount} 位成员',
                  style: const TextStyle(color: Color(0xFF858792)),
                ),
                const SizedBox(height: 10),
                const Text(
                  '交流创作经验、分享实用工具，与同频创作者共同成长。',
                  textAlign: TextAlign.center,
                  style: TextStyle(height: 1.45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '群成员',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${widget.memberCount}人',
                      style: const TextStyle(color: Color(0xFF8B8D98)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ...members.map(
                      (name) => Expanded(
                        child: Column(
                          children: [
                            ChatAvatar.person(name: name, radius: 20),
                            const SizedBox(height: 5),
                            Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        key: const Key('invite-member'),
                        onTap: () => showMessage('邀请链接已生成'),
                        child: const Column(
                          children: [
                            CircleAvatar(child: Icon(Icons.add_rounded)),
                            SizedBox(height: 5),
                            Text('邀请', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _InfoTile(
            title: '群公告',
            subtitle: '请遵守群规，友善交流，共同成长。',
            onTap: () => showMessage('群公告已展开'),
          ),
          _InfoTile(
            title: '群规则',
            subtitle: '禁止广告、骚扰、违法及侵权内容',
            onTap: () => showMessage('群规则已展开'),
          ),
          if (widget.session != null && widget.conversationId != null)
            ListTile(
              key: const Key('group-management-entry'),
              tileColor: Colors.white,
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('群管理'),
              subtitle: const Text('群公告、成员、管理员与入群设置'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => GroupManagementScreen(
                    session: widget.session!,
                    conversationId: widget.conversationId!,
                    groupName: widget.groupName,
                    memberCount: widget.memberCount,
                  ),
                ),
              ),
            ),
          SwitchListTile(
            tileColor: Colors.white,
            title: const Text('消息通知'),
            value: notificationsEnabled,
            onChanged: (value) => setState(() => notificationsEnabled = value),
          ),
          const SizedBox(height: 10),
          ListTile(
            key: const Key('exit-group'),
            tileColor: Colors.white,
            title: const Center(
              child: Text('退出群聊', style: TextStyle(color: Colors.red)),
            ),
            onTap: () async {
              final exit = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('退出群聊？'),
                  content: const Text('退出后将不再接收此群消息。'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('确认退出'),
                    ),
                  ],
                ),
              );
              if (exit == true && context.mounted) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    tileColor: Colors.white,
    title: Text(title),
    subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
