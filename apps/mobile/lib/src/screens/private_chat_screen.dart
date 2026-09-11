import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_session.dart';
import '../chat/chat_api.dart';
import '../widgets/chat_avatar.dart';

enum _PrivateMessageType { text, image, video, content }

class _PrivateMessage {
  _PrivateMessage({
    required this.id,
    required this.text,
    required this.mine,
    this.type = _PrivateMessageType.text,
    this.reply,
    this.replyToMessageId,
    this.sending = false,
  });

  String id;
  final String text;
  final bool mine;
  final _PrivateMessageType type;
  final String? reply;
  final int? replyToMessageId;
  bool sending;
  bool recalled = false;
}

class PrivateChatScreen extends StatefulWidget {
  const PrivateChatScreen({
    super.key,
    required this.name,
    required this.currentUser,
    this.conversationId,
    this.session,
  });

  final String name;
  final String currentUser;
  final String? conversationId;
  final AuthSession? session;

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final ChatApi chatApi = ChatApi();
  final input = TextEditingController();
  final scrollController = ScrollController();
  final focusNode = FocusNode();
  final List<_PrivateMessage> messages = [
    _PrivateMessage(id: '1', text: '你好，我很喜欢你分享的社区设计思路。', mine: false),
    _PrivateMessage(id: '2', text: '谢谢！欢迎一起交流。', mine: true),
    _PrivateMessage(
      id: '3',
      text: '社区产品如何把内容浏览变成真实关系？',
      mine: false,
      type: _PrivateMessageType.content,
    ),
  ];
  _PrivateMessage? replyingTo;
  bool blocked = false;
  bool loadingHistory = false;
  bool showEmojiPanel = false;

  @override
  void initState() {
    super.initState();
    if (widget.session?.signedIn == true) {
      unawaited(loadRemoteMessages());
    }
  }

  String get resolvedConversationId =>
      widget.conversationId ?? (widget.name == '小宇' ? 'xiaoyu' : 'luna');

  Future<void> loadRemoteMessages() async {
    final token = widget.session?.accessToken;
    if (token == null) return;
    try {
      final remote = await chatApi.messages(token, resolvedConversationId);
      if (!mounted) return;
      final contentById = {for (final item in remote) item.id: item.content};
      setState(() {
        messages
          ..clear()
          ..addAll(
            remote.map(
              (item) => _PrivateMessage(
                id: item.id.toString(),
                text: item.content,
                mine:
                    item.senderId > 0 && item.senderName == widget.currentUser,
                type: privateMessageType(item.type),
                reply: contentById[item.replyToMessageId],
                replyToMessageId: item.replyToMessageId == 0
                    ? null
                    : item.replyToMessageId,
              ),
            ),
          );
      });
      if (remote.isNotEmpty) {
        await chatApi.markRead(token, resolvedConversationId, remote.last.id);
      }
      scrollToBottom();
    } on ChatApiException catch (error) {
      if (mounted) showMessage(error.message);
    }
  }

  _PrivateMessageType privateMessageType(String value) => switch (value) {
    'image' => _PrivateMessageType.image,
    'video' => _PrivateMessageType.video,
    'content' => _PrivateMessageType.content,
    _ => _PrivateMessageType.text,
  };

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

  void scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !scrollController.hasClients) return;
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  void sendText() {
    final value = input.text.trim();
    if (blocked || value.isEmpty) return;
    final message = _PrivateMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: value,
      mine: true,
      reply: replyingTo?.text,
      replyToMessageId: int.tryParse(replyingTo?.id ?? ''),
      sending: true,
    );
    setState(() {
      messages.add(message);
      replyingTo = null;
      showEmojiPanel = false;
      input.clear();
    });
    scrollToBottom();
    unawaited(completeSend(message));
  }

  Future<void> completeSend(_PrivateMessage message) async {
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
          message.sending = false;
        });
        return;
      } on ChatApiException catch (error) {
        if (!mounted || !messages.contains(message)) return;
        setState(() => message.sending = false);
        showMessage(error.message);
        return;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted || !messages.contains(message)) return;
    setState(() => message.sending = false);
  }

  void sendMedia(_PrivateMessageType type, String text) {
    final message = _PrivateMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      text: text,
      mine: true,
      type: type,
      sending: true,
    );
    setState(() {
      messages.add(message);
      showEmojiPanel = false;
    });
    Navigator.pop(context);
    scrollToBottom();
    unawaited(completeSend(message));
  }

  Future<void> loadHistory() async {
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
              (item) => _PrivateMessage(
                id: item.id.toString(),
                text: item.content,
                mine:
                    item.senderId > 0 && item.senderName == widget.currentUser,
                type: privateMessageType(item.type),
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
      messages.insert(
        0,
        _PrivateMessage(id: 'history', text: '你好，可以认识一下吗？', mine: false),
      );
      loadingHistory = false;
    });
  }

  Future<void> showProfile() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChatAvatar.person(name: widget.name, radius: 34),
              const SizedBox(height: 10),
              Text(
                widget.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                '产品设计师 · 12.8k 粉丝',
                style: TextStyle(color: Color(0xFF858792)),
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('查看个人主页'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> showConversationMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: const Text('举报用户'),
              onTap: () {
                Navigator.pop(sheetContext);
                showMessage('举报已提交');
              },
            ),
            ListTile(
              key: const Key('block-user'),
              leading: Icon(
                blocked ? Icons.check_circle_outline : Icons.block_rounded,
              ),
              title: Text(blocked ? '解除拉黑' : '拉黑用户'),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() {
                  blocked = !blocked;
                  if (blocked) {
                    replyingTo = null;
                    showEmojiPanel = false;
                  }
                });
                if (blocked) focusNode.unfocus();
                showMessage(blocked ? '已拉黑 ${widget.name}' : '已解除拉黑');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showMessageActions(_PrivateMessage message) async {
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
            if (message.type == _PrivateMessageType.text)
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
            if (message.mine)
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
                title: const Text('举报消息'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showMessage('消息举报已提交');
                },
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
              _MediaChoice(
                key: const Key('private-send-image'),
                icon: Icons.image_outlined,
                label: '图片',
                onTap: () => sendMedia(_PrivateMessageType.image, '我分享了一张图片'),
              ),
              _MediaChoice(
                key: const Key('private-send-video'),
                icon: Icons.videocam_outlined,
                label: '视频',
                onTap: () => sendMedia(_PrivateMessageType.video, '我分享了一段视频'),
              ),
              _MediaChoice(
                key: const Key('private-send-content'),
                icon: Icons.article_outlined,
                label: '内容',
                onTap: () =>
                    sendMedia(_PrivateMessageType.content, '我分享了一篇社区内容'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        titleSpacing: 0,
        title: InkWell(
          key: const Key('private-profile-entry'),
          onTap: showProfile,
          child: Row(
            children: [
              ChatAvatar.person(name: widget.name, radius: 17),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Text(
                    '在线',
                    style: TextStyle(fontSize: 11, color: Colors.green),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            key: const Key('private-menu'),
            onPressed: showConversationMenu,
            icon: const Icon(Icons.more_horiz_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              key: const Key('private-message-list'),
              controller: scrollController,
              padding: const EdgeInsets.all(14),
              itemCount: messages.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Center(
                    child: TextButton.icon(
                      key: const Key('private-load-history'),
                      onPressed: loadingHistory ? null : loadHistory,
                      icon: const Icon(Icons.history_rounded),
                      label: Text(loadingHistory ? '加载中…' : '加载更早消息'),
                    ),
                  );
                }
                final message = messages[index - 1];
                if (message.recalled) {
                  return const Padding(
                    padding: EdgeInsets.all(10),
                    child: Center(child: Text('你撤回了一条消息')),
                  );
                }
                return _PrivateMessageRow(
                  message: message,
                  friendName: widget.name,
                  currentUser: widget.currentUser,
                  onLongPress: () => showMessageActions(message),
                );
              },
            ),
          ),
          if (blocked)
            const MaterialBanner(
              key: Key('blocked-notice'),
              content: Text('你已拉黑对方，无法继续发送消息。'),
              actions: [SizedBox.shrink()],
            ),
          if (replyingTo != null)
            Container(
              key: const Key('private-reply-preview'),
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '回复 ${widget.name}：${replyingTo!.text}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF72747F),
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('private-cancel-reply'),
                    onPressed: () => setState(() => replyingTo = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
          SafeArea(
            top: false,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('private-input'),
                      controller: input,
                      focusNode: focusNode,
                      enabled: !blocked,
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
                    key: const Key('private-emoji-button'),
                    tooltip: '表情',
                    onPressed: blocked
                        ? null
                        : () {
                            setState(() => showEmojiPanel = !showEmojiPanel);
                            if (showEmojiPanel) focusNode.unfocus();
                          },
                    icon: const Icon(Icons.sentiment_satisfied_alt_rounded),
                  ),
                  IconButton(
                    key: const Key('private-attachment-button'),
                    tooltip: '添加',
                    onPressed: blocked ? null : showAttachments,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                  IconButton(
                    key: const Key('private-send'),
                    tooltip: '发送',
                    onPressed: blocked ? null : sendText,
                    icon: const Icon(
                      Icons.send_rounded,
                      color: Color(0xFF6256E8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showEmojiPanel)
            _PrivateEmojiPanel(
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

class _PrivateMessageRow extends StatelessWidget {
  const _PrivateMessageRow({
    required this.message,
    required this.friendName,
    required this.currentUser,
    required this.onLongPress,
  });

  final _PrivateMessage message;
  final String friendName;
  final String currentUser;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final messageContent = Expanded(
      child: Column(
        crossAxisAlignment: message.mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          if (!message.mine) ...[
            Text(
              friendName,
              key: Key('private-friend-nickname-${message.id}'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF777984),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
          ],
          GestureDetector(
            onLongPress: onLongPress,
            child: Container(
              key: Key('private-message-${message.id}'),
              constraints: const BoxConstraints(maxWidth: 245),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.mine ? const Color(0xFF6A5CFF) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(message.mine ? 16 : 5),
                  topRight: Radius.circular(message.mine ? 5 : 16),
                  bottomLeft: const Radius.circular(16),
                  bottomRight: const Radius.circular(16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.reply != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 7),
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Text(
                        message.reply!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (message.type == _PrivateMessageType.image ||
                      message.type == _PrivateMessageType.video)
                    Container(
                      width: 180,
                      height: 100,
                      margin: const EdgeInsets.only(bottom: 7),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34394E), Color(0xFF7568CC)],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        message.type == _PrivateMessageType.image
                            ? Icons.image_rounded
                            : Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    )
                  else if (message.type == _PrivateMessageType.content)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.article_outlined),
                          SizedBox(width: 7),
                          Text('社区内容卡片'),
                        ],
                      ),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.mine
                          ? Colors.white
                          : const Color(0xFF292A32),
                    ),
                  ),
                  if (message.sending)
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: SizedBox.square(
                        dimension: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: message.mine
            ? [
                messageContent,
                const SizedBox(width: 9),
                _PrivateChatAvatar(
                  key: Key('private-own-avatar-${message.id}'),
                  name: currentUser,
                  mine: true,
                ),
              ]
            : [
                _PrivateChatAvatar(
                  key: Key('private-friend-avatar-${message.id}'),
                  name: friendName,
                  mine: false,
                ),
                const SizedBox(width: 9),
                messageContent,
              ],
      ),
    );
  }
}

class _PrivateChatAvatar extends StatelessWidget {
  const _PrivateChatAvatar({super.key, required this.name, required this.mine});

  final String name;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final normalizedName = name.trim();
    return Semantics(
      label: mine ? '我的头像' : '$normalizedName 的头像',
      child: ChatAvatar.person(
        name: normalizedName.isEmpty ? '我' : normalizedName,
        radius: 19,
        emphasized: mine,
      ),
    );
  }
}

class _MediaChoice extends StatelessWidget {
  const _MediaChoice({
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

class _PrivateEmojiPanel extends StatelessWidget {
  const _PrivateEmojiPanel({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const emojis = ['😀', '😂', '😍', '👍', '🎉', '🔥', '👏', '💡', '❤️', '🤝'];
    return Container(
      key: const Key('private-emoji-panel'),
      height: 105,
      color: Colors.white,
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: emojis
            .map(
              (emoji) => InkWell(
                key: Key('private-emoji-$emoji'),
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
