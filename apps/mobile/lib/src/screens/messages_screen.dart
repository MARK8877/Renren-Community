import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_session.dart';
import '../chat/chat_api.dart';
import '../friend/friend_api.dart';
import 'group_chat_screen.dart';
import 'private_chat_screen.dart';
import 'video_feed_screen.dart';
import '../widgets/chat_avatar.dart';
import 'create_group_screen.dart';
import 'group_list_screen.dart';

enum ConversationType { private, group }

List<String> conversationAvatarMembers(ConversationItem item) {
  switch (item.id) {
    case 'group-ai':
      return const ['Kevin AI', 'Luna', '小宇', '阿杰'];
    case 'group-product':
      return const ['阿杰', 'Luna', '小宇', 'Kevin AI'];
    case 'group-event':
      return const ['陈晨', '小宇', 'Luna', '阿杰'];
  }

  final memberCount = int.tryParse(
    item.memberCount.replaceAll(RegExp(r'[^0-9]'), ''),
  );
  final avatarCount = memberCount == null ? 4 : memberCount.clamp(4, 9).toInt();
  return List.generate(avatarCount, (index) => '${item.name}成员${index + 1}');
}

class ConversationItem {
  ConversationItem({
    required this.id,
    required this.name,
    required this.message,
    required this.time,
    required this.updatedAt,
    required this.type,
    this.lastMessageId = 0,
    this.memberCount = '',
    this.unread = 0,
    this.muted = false,
    this.pinned = false,
  });

  final String id;
  final String name;
  final String message;
  final String time;
  final DateTime updatedAt;
  final ConversationType type;
  final int lastMessageId;
  final String memberCount;
  int unread;
  bool muted;
  bool pinned;
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    required this.session,
    this.onOpenVideo,
    this.showBottomNavigation = true,
  });

  final AuthSession session;
  final VoidCallback? onOpenVideo;
  final bool showBottomNavigation;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ChatApi chatApi = ChatApi();
  final FriendApi friendApi = FriendApi();
  final PageController sectionController = PageController();
  final Set<String> hiddenConversationIds = {};
  final Set<String> pinnedConversationIds = {};
  final List<FriendUserData> remoteFriends = [];
  final List<FriendRequestData> incomingFriendRequests = [];
  Timer? friendRefreshTimer;
  int selectedSection = 0;
  final List<ConversationItem> conversations = [
    ConversationItem(
      id: 'group-product',
      name: '产品设计交流社区',
      message: '阿杰：有人参加本周线上讨论吗？',
      time: '昨天',
      updatedAt: DateTime(2026, 9, 7, 20, 10),
      type: ConversationType.group,
      unread: 5,
    ),
    ConversationItem(
      id: 'luna',
      name: 'Luna Design',
      message: '这版交互思路很清晰，可以继续完善',
      time: '11:20',
      updatedAt: DateTime(2026, 9, 8, 11, 20),
      type: ConversationType.private,
      unread: 2,
    ),
    ConversationItem(
      id: 'xiaoyu',
      name: '小宇',
      message: '好的，稍后发给你',
      time: '周五',
      updatedAt: DateTime(2026, 9, 4, 18, 30),
      type: ConversationType.private,
    ),
    ConversationItem(
      id: 'group-ai',
      name: 'AI 视频创作者交流群',
      message: 'Kevin AI：今晚分享完整工作流',
      time: '12:36',
      updatedAt: DateTime(2026, 9, 8, 12, 36),
      type: ConversationType.group,
      unread: 12,
    ),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.session.signedIn) {
      unawaited(initializeConversations());
      friendRefreshTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => unawaited(loadFriendData(silent: true)),
      );
    }
  }

  @override
  void dispose() {
    friendRefreshTimer?.cancel();
    sectionController.dispose();
    super.dispose();
  }

  String get preferenceSuffix => widget.session.nickname;
  String get hiddenPreferenceKey => 'hidden_conversations:$preferenceSuffix';
  String get pinnedPreferenceKey => 'pinned_conversations:$preferenceSuffix';

  Future<void> initializeConversations() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      hiddenConversationIds.addAll(
        preferences.getStringList(hiddenPreferenceKey) ?? const [],
      );
      pinnedConversationIds.addAll(
        preferences.getStringList(pinnedPreferenceKey) ?? const [],
      );
    } catch (_) {}
    await Future.wait([loadConversations(), loadFriendData()]);
  }

  Future<void> loadFriendData({bool silent = false}) async {
    final token = widget.session.accessToken;
    if (token == null) return;
    try {
      final friends = await friendApi.friends(token);
      final requests = await friendApi.incomingRequests(token);
      if (!mounted) return;
      setState(() {
        remoteFriends
          ..clear()
          ..addAll(friends);
        incomingFriendRequests
          ..clear()
          ..addAll(requests);
      });
    } on FriendApiException catch (error) {
      if (mounted && !silent) showMessage(error.message);
    }
  }

  Future<void> saveConversationPreferences() async {
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setStringList(
        hiddenPreferenceKey,
        hiddenConversationIds.toList(),
      );
      await preferences.setStringList(
        pinnedPreferenceKey,
        pinnedConversationIds.toList(),
      );
    } catch (_) {}
  }

  Future<void> loadConversations() async {
    final token = widget.session.accessToken;
    if (token == null) return;
    try {
      final remote = await chatApi.conversations(token);
      if (!mounted) return;
      setState(() {
        conversations
          ..clear()
          ..addAll(
            remote
                .where((item) => !hiddenConversationIds.contains(item.id))
                .map(
                  (item) => ConversationItem(
                    id: item.id,
                    name: item.name,
                    message: item.lastSender.isEmpty || item.type == 'private'
                        ? item.lastMessage
                        : '${item.lastSender}：${item.lastMessage}',
                    time: formatConversationTime(item.updatedAt),
                    updatedAt: item.updatedAt,
                    type: item.type == 'group'
                        ? ConversationType.group
                        : ConversationType.private,
                    lastMessageId: item.lastMessageId,
                    memberCount: item.memberCount,
                    unread: item.unreadCount,
                    muted: item.muted,
                    pinned:
                        item.pinned || pinnedConversationIds.contains(item.id),
                  ),
                ),
          );
      });
    } on ChatApiException catch (error) {
      if (mounted) showMessage(error.message);
    }
  }

  String formatConversationTime(DateTime value) {
    final now = DateTime.now();
    if (value.year == now.year &&
        value.month == now.month &&
        value.day == now.day) {
      return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    }
    return '${value.month}/${value.day}';
  }

  List<ConversationItem> get sortedConversations {
    final items = List<ConversationItem>.of(conversations);
    items.sort((first, second) {
      if (first.pinned != second.pinned) {
        return first.pinned ? -1 : 1;
      }
      return second.updatedAt.compareTo(first.updatedAt);
    });
    return items;
  }

  int get totalUnread =>
      conversations.fold(0, (sum, item) => sum + item.unread);

  List<ConversationItem> get contacts {
    final uniqueContacts = <String, ConversationItem>{};
    for (final item in conversations) {
      if (item.type == ConversationType.private) {
        uniqueContacts[item.id] = item;
      }
    }
    for (final friend in remoteFriends) {
      final conversationID = friend.conversationId.isEmpty
          ? 'friend-${friend.id}'
          : friend.conversationId;
      uniqueContacts[conversationID] = ConversationItem(
        id: conversationID,
        name: friend.nickname,
        message: '点击开始聊天',
        time: '',
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        type: ConversationType.private,
      );
    }
    final items = uniqueContacts.values.toList();
    items.sort((first, second) => first.name.compareTo(second.name));
    return items;
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> handleComposeAction(String action) async {
    if (!mounted) return;
    switch (action) {
      case 'group':
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) => CreateGroupScreen(session: widget.session),
          ),
        );
      case 'add-friend':
        await openAddContact();
      case 'friend-requests':
        await openFriendRequests();
    }
  }

  Future<void> openConversation(ConversationItem item) async {
    setState(() => item.unread = 0);
    final token = widget.session.accessToken;
    if (token != null && item.lastMessageId > 0) {
      try {
        await chatApi.markRead(token, item.id, item.lastMessageId);
      } on ChatApiException catch (error) {
        if (mounted) showMessage(error.message);
      }
    }
    if (!mounted) return;
    if (item.type == ConversationType.group) {
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => GroupChatScreen(
            groupName: item.name,
            memberCount: item.memberCount.isNotEmpty
                ? item.memberCount
                : item.id == 'group-ai'
                ? '2,856'
                : '18,420',
            currentUser: widget.session.nickname,
            conversationId: item.id,
            session: widget.session,
          ),
        ),
      );
      if (widget.session.signedIn) await loadConversations();
      return;
    }
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PrivateChatScreen(
          name: item.name,
          currentUser: widget.session.nickname,
          conversationId: item.id,
          session: widget.session,
        ),
      ),
    );
    if (widget.session.signedIn) await loadConversations();
  }

  void selectSection(int index) {
    if (selectedSection == index) {
      if (index == 1 && widget.session.signedIn) {
        unawaited(loadFriendData(silent: true));
      }
      return;
    }
    setState(() => selectedSection = index);
    sectionController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Future<List<FriendUserData>> searchUsers(String keyword) async {
    final token = widget.session.accessToken;
    if (token != null) return friendApi.search(token, keyword);
    final normalized = keyword.trim().toLowerCase();
    return contacts
        .where((contact) => contact.name.toLowerCase().contains(normalized))
        .map(
          (contact) => FriendUserData(
            id: contact.id.hashCode.abs(),
            nickname: contact.name,
            relationship: 'friend',
            conversationId: contact.id,
          ),
        )
        .toList();
  }

  Future<bool> sendFriendRequest(FriendUserData user) async {
    final token = widget.session.accessToken;
    if (token == null) {
      showMessage('请登录后添加好友');
      return false;
    }
    try {
      await friendApi.sendRequest(token, user.id);
      if (mounted) showMessage('好友申请已发送');
      return true;
    } on FriendApiException catch (error) {
      if (mounted) showMessage(error.message);
      return false;
    }
  }

  Future<bool> respondFriendRequest(
    FriendRequestData request,
    bool accept,
  ) async {
    final token = widget.session.accessToken;
    if (token == null) return false;
    try {
      if (accept) {
        await friendApi.accept(token, request.id);
      } else {
        await friendApi.reject(token, request.id);
      }
      if (!mounted) return false;
      setState(() => incomingFriendRequests.remove(request));
      if (accept) {
        await Future.wait([loadFriendData(), loadConversations()]);
      }
      if (mounted) showMessage(accept ? '已添加为好友' : '已拒绝好友申请');
      return true;
    } on FriendApiException catch (error) {
      if (mounted) showMessage(error.message);
      return false;
    }
  }

  Future<void> openAddContact() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _AddContactScreen(
          onSearch: searchUsers,
          onSendRequest: sendFriendRequest,
        ),
      ),
    );
  }

  Future<void> openFriendRequests() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => _FriendRequestsScreen(
          requests: incomingFriendRequests,
          onRespond: respondFriendRequest,
        ),
      ),
    );
  }

  Future<void> openGroups() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GroupListScreen(
          session: widget.session,
          groups: conversations
              .where((item) => item.type == ConversationType.group)
              .toList(),
          onGroupLeft: (conversationId) {
            if (!mounted) return;
            setState(
              () => conversations.removeWhere(
                (item) => item.id == conversationId,
              ),
            );
          },
        ),
      ),
    );
  }

  void togglePinned(ConversationItem item) {
    setState(() {
      item.pinned = !item.pinned;
      if (item.pinned) {
        pinnedConversationIds.add(item.id);
      } else {
        pinnedConversationIds.remove(item.id);
      }
    });
    unawaited(saveConversationPreferences());
  }

  void deleteConversation(ConversationItem item) {
    setState(() {
      conversations.remove(item);
      hiddenConversationIds.add(item.id);
      pinnedConversationIds.remove(item.id);
    });
    unawaited(saveConversationPreferences());
    showMessage('已删除会话');
  }

  @override
  Widget build(BuildContext context) {
    final displayItems = sortedConversations;
    return Scaffold(
      key: const Key('messages-main-screen'),
      backgroundColor: const Color(0xFFF6F6F9),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        title: Row(
          children: [
            _MessagesHeaderTab(
              key: const Key('messages-section-tab'),
              label: '消息',
              selected: selectedSection == 0,
              badge: totalUnread,
              onTap: () => selectSection(0),
            ),
            const SizedBox(width: 22),
            _MessagesHeaderTab(
              key: const Key('contacts-section-tab'),
              label: '联系人',
              selected: selectedSection == 1,
              badge: incomingFriendRequests.length,
              onTap: () => selectSection(1),
            ),
          ],
        ),
        actions: selectedSection == 0
            ? [
                Theme(
                  data: Theme.of(context).copyWith(
                    hoverColor: const Color(0xFFE5E7EB),
                    highlightColor: const Color(0xFFE5E7EB),
                    splashColor: const Color(0xFFE5E7EB),
                  ),
                  child: PopupMenuButton<String>(
                    key: const Key('messages-compose-actions'),
                    tooltip: '发起操作',
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 8),
                    color: const Color(0xFF6256E8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    onSelected: handleComposeAction,
                    itemBuilder: (context) => const [
                      PopupMenuItem<String>(
                        key: Key('compose-start-group'),
                        value: 'group',
                        textStyle: TextStyle(color: Colors.black),
                        child: Row(
                          children: [
                            Icon(Icons.group_add_rounded),
                            SizedBox(width: 10),
                            Text('发起群聊'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        key: Key('compose-add-friend'),
                        value: 'add-friend',
                        textStyle: TextStyle(color: Colors.black),
                        child: Row(
                          children: [
                            Icon(Icons.person_add_alt_1_rounded),
                            SizedBox(width: 10),
                            Text('添加好友'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        key: Key('compose-friend-requests'),
                        value: 'friend-requests',
                        textStyle: TextStyle(color: Colors.black),
                        child: Row(
                          children: [
                            Icon(Icons.how_to_reg_rounded),
                            SizedBox(width: 10),
                            Text('新的好友'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ]
            : null,
      ),
      body: PageView(
        key: const Key('messages-contacts-pages'),
        controller: sectionController,
        onPageChanged: (index) {
          if (selectedSection != index) {
            setState(() => selectedSection = index);
          }
          if (index == 1 && widget.session.signedIn) {
            unawaited(loadFriendData(silent: true));
          }
        },
        children: [
          displayItems.isEmpty
              ? const Center(
                  child: Text(
                    '暂无会话',
                    style: TextStyle(color: Color(0xFF8B8D98)),
                  ),
                )
              : ListView.separated(
                  key: const Key('unified-conversation-list'),
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  itemCount: displayItems.length,
                  itemBuilder: (context, index) {
                    final item = displayItems[index];
                    return _SwipeConversationTile(
                      key: ValueKey('swipe-${item.id}'),
                      item: item,
                      onTap: () => openConversation(item),
                      onPin: () => togglePinned(item),
                      onDelete: () => deleteConversation(item),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 76),
                ),
          _ContactsPanel(
            contacts: contacts,
            groups: conversations
                .where((item) => item.type == ConversationType.group)
                .toList(),
            pendingRequestCount: incomingFriendRequests.length,
            onAddContact: openAddContact,
            onOpenFriendRequests: openFriendRequests,
            onOpenGroups: openGroups,
            onOpenContact: openConversation,
          ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNavigation
          ? _MessagesBottomNavigation(
              onHome: () => Navigator.pop(context),
              onVideo: () {
                final onOpenVideo = widget.onOpenVideo;
                if (onOpenVideo != null) {
                  onOpenVideo();
                  return;
                }
                Navigator.push<void>(
                  context,
                  PageRouteBuilder<void>(
                    transitionDuration: const Duration(milliseconds: 220),
                    reverseTransitionDuration: const Duration(
                      milliseconds: 180,
                    ),
                    pageBuilder: (context, animation, secondaryAnimation) =>
                        VideoFeedScreen(session: widget.session),
                    transitionsBuilder:
                        (context, animation, secondaryAnimation, child) =>
                            FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
              onUnavailable: (label) => showMessage('$label页面开发中'),
            )
          : null,
    );
  }
}

class _MessagesHeaderTab extends StatelessWidget {
  const _MessagesHeaderTab({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: selected ? 20 : 17,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFF22232A)
                      : const Color(0xFF8B8D98),
                ),
              ),
              if (badge > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 19),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4D67),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge > 99 ? '99+' : '$badge',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: selected ? 22 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: const Color(0xFF6256E8),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ContactsPanel extends StatefulWidget {
  const _ContactsPanel({
    required this.contacts,
    required this.groups,
    required this.pendingRequestCount,
    required this.onAddContact,
    required this.onOpenFriendRequests,
    required this.onOpenGroups,
    required this.onOpenContact,
  });

  final List<ConversationItem> contacts;
  final List<ConversationItem> groups;
  final int pendingRequestCount;
  final VoidCallback onAddContact;
  final VoidCallback onOpenFriendRequests;
  final VoidCallback onOpenGroups;
  final Future<void> Function(ConversationItem contact) onOpenContact;

  @override
  State<_ContactsPanel> createState() => _ContactsPanelState();
}

class _ContactsPanelState extends State<_ContactsPanel> {
  String keyword = '';

  List<ConversationItem> get filteredContacts {
    final normalizedKeyword = keyword.trim().toLowerCase();
    if (normalizedKeyword.isEmpty) return widget.contacts;
    return widget.contacts
        .where(
          (contact) => contact.name.toLowerCase().contains(normalizedKeyword),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = filteredContacts;
    return Column(
      key: const Key('contacts-panel'),
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            key: const Key('contacts-search'),
            onChanged: (value) => setState(() => keyword = value),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: '搜索联系人',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: const Color(0xFFF2F2F5),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Material(
          color: Colors.white,
          child: Column(
            children: [
              ListTile(
                key: const Key('contacts-groups-entry'),
                onTap: widget.onOpenGroups,
                leading: const _ContactFeatureIcon(
                  color: Color(0xFF2BAA7A),
                  icon: Icons.groups_2_rounded,
                ),
                title: const Text(
                  '群组',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('${widget.groups.length} 个群聊，统一管理群资料与成员'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                key: const Key('add-contact-entry'),
                onTap: widget.onAddContact,
                leading: const _ContactFeatureIcon(
                  color: Color(0xFF6256E8),
                  icon: Icons.person_add_alt_1_rounded,
                ),
                title: const Text(
                  '添加联系人',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text('搜索昵称、邮箱或手机号'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
              const Divider(height: 1, indent: 72),
              ListTile(
                key: const Key('new-friends-entry'),
                onTap: widget.onOpenFriendRequests,
                leading: Badge(
                  isLabelVisible: widget.pendingRequestCount > 0,
                  label: Text('${widget.pendingRequestCount}'),
                  child: const _ContactFeatureIcon(
                    color: Color(0xFFFF9F43),
                    icon: Icons.group_add_rounded,
                  ),
                ),
                title: const Text(
                  '新的好友',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  widget.pendingRequestCount > 0
                      ? '${widget.pendingRequestCount} 条申请待处理'
                      : '暂无新的好友申请',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    '未找到联系人',
                    style: TextStyle(color: Color(0xFF8B8D98)),
                  ),
                )
              : ListView.separated(
                  key: const Key('contacts-list'),
                  padding: const EdgeInsets.only(top: 8, bottom: 24),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final contact = items[index];
                    return Material(
                      color: Colors.white,
                      child: ListTile(
                        key: Key('contact-${contact.id}'),
                        onTap: () => widget.onOpenContact(contact),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE2F0FF),
                          child: Text(
                            contact.name.characters.first,
                            style: const TextStyle(
                              color: Color(0xFF6256E8),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          contact.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 72),
                ),
        ),
      ],
    );
  }
}

class _ContactFeatureIcon extends StatelessWidget {
  const _ContactFeatureIcon({required this.color, required this.icon});

  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: Colors.white, size: 23),
  );
}

class _AddContactScreen extends StatefulWidget {
  const _AddContactScreen({
    required this.onSearch,
    required this.onSendRequest,
  });

  final Future<List<FriendUserData>> Function(String keyword) onSearch;
  final Future<bool> Function(FriendUserData user) onSendRequest;

  @override
  State<_AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends State<_AddContactScreen> {
  final TextEditingController searchController = TextEditingController();
  List<FriendUserData> results = [];
  bool searching = false;
  String message = '输入昵称、邮箱或手机号查找用户';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final keyword = searchController.text.trim();
    if (keyword.length < 2) {
      setState(() => message = '请输入至少 2 个字符');
      return;
    }
    setState(() {
      searching = true;
      message = '';
    });
    try {
      final items = await widget.onSearch(keyword);
      if (!mounted) return;
      setState(() {
        results = items;
        message = items.isEmpty ? '未找到相关用户' : '';
      });
    } on FriendApiException catch (error) {
      if (mounted) setState(() => message = error.message);
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  Future<void> sendRequest(FriendUserData user, int index) async {
    final sent = await widget.onSendRequest(user);
    if (!sent || !mounted) return;
    setState(() {
      results[index] = FriendUserData(
        id: user.id,
        nickname: user.nickname,
        relationship: 'outgoing_pending',
        avatarUrl: user.avatarUrl,
        identifier: user.identifier,
        conversationId: user.conversationId,
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('add-contact-screen'),
    backgroundColor: const Color(0xFFF6F6F9),
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('添加联系人', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: TextField(
            key: const Key('add-contact-search'),
            controller: searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => search(),
            decoration: InputDecoration(
              hintText: '搜索昵称、邮箱或手机号',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: IconButton(
                key: const Key('add-contact-search-button'),
                onPressed: searching ? null : search,
                icon: const Icon(Icons.arrow_forward_rounded),
              ),
              filled: true,
              fillColor: const Color(0xFFF2F2F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        if (searching) const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: results.isEmpty
              ? Center(
                  child: Text(
                    message,
                    style: const TextStyle(color: Color(0xFF8B8D98)),
                  ),
                )
              : ListView.separated(
                  key: const Key('add-contact-results'),
                  padding: const EdgeInsets.only(top: 8),
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final user = results[index];
                    final canAdd = user.relationship == 'none';
                    final buttonLabel = switch (user.relationship) {
                      'friend' => '已添加',
                      'outgoing_pending' => '已申请',
                      'incoming_pending' => '待你处理',
                      _ => '添加',
                    };
                    return Material(
                      color: Colors.white,
                      child: ListTile(
                        key: Key('search-user-${user.id}'),
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFE2F0FF),
                          child: Text(user.nickname.characters.first),
                        ),
                        title: Text(
                          user.nickname,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: user.identifier.isEmpty
                            ? null
                            : Text(user.identifier),
                        trailing: FilledButton.tonal(
                          key: Key('send-friend-request-${user.id}'),
                          onPressed: canAdd
                              ? () => sendRequest(user, index)
                              : null,
                          child: Text(buttonLabel),
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 72),
                ),
        ),
      ],
    ),
  );
}

class _FriendRequestsScreen extends StatefulWidget {
  const _FriendRequestsScreen({
    required this.requests,
    required this.onRespond,
  });

  final List<FriendRequestData> requests;
  final Future<bool> Function(FriendRequestData request, bool accept) onRespond;

  @override
  State<_FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<_FriendRequestsScreen> {
  late final List<FriendRequestData> requests = List.of(widget.requests);
  final Set<int> processing = {};

  Future<void> respond(FriendRequestData request, bool accept) async {
    setState(() => processing.add(request.id));
    final success = await widget.onRespond(request, accept);
    if (!mounted) return;
    setState(() {
      processing.remove(request.id);
      if (success) requests.remove(request);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    key: const Key('friend-requests-screen'),
    backgroundColor: const Color(0xFFF6F6F9),
    appBar: AppBar(
      backgroundColor: Colors.white,
      title: const Text('新的好友', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: requests.isEmpty
        ? const Center(
            child: Text('暂无新的好友申请', style: TextStyle(color: Color(0xFF8B8D98))),
          )
        : ListView.separated(
            key: const Key('friend-requests-list'),
            padding: const EdgeInsets.only(top: 8),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final disabled = processing.contains(request.id);
              return Material(
                color: Colors.white,
                child: ListTile(
                  key: Key('friend-request-${request.id}'),
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFFFEAD6),
                    child: Text(request.nickname.characters.first),
                  ),
                  title: Text(
                    request.nickname,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('请求添加你为好友'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        key: Key('reject-friend-request-${request.id}'),
                        onPressed: disabled
                            ? null
                            : () => respond(request, false),
                        child: const Text('拒绝'),
                      ),
                      FilledButton(
                        key: Key('accept-friend-request-${request.id}'),
                        onPressed: disabled
                            ? null
                            : () => respond(request, true),
                        child: const Text('同意'),
                      ),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 72),
          ),
  );
}

class _SwipeConversationTile extends StatefulWidget {
  const _SwipeConversationTile({
    super.key,
    required this.item,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
  });

  final ConversationItem item;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  @override
  State<_SwipeConversationTile> createState() => _SwipeConversationTileState();
}

class _SwipeConversationTileState extends State<_SwipeConversationTile> {
  static const actionWidth = 148.0;
  double offset = 0;

  void closeActions() {
    if (offset != 0) setState(() => offset = 0);
  }

  @override
  Widget build(BuildContext context) => ClipRect(
    child: Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              width: actionWidth,
              child: Row(
                children: [
                  Expanded(
                    child: _SwipeAction(
                      key: Key('pin-conversation-${widget.item.id}'),
                      color: const Color(0xFFF2A53B),
                      icon: widget.item.pinned
                          ? Icons.vertical_align_center_rounded
                          : Icons.vertical_align_top_rounded,
                      label: widget.item.pinned ? '取消置顶' : '置顶',
                      onTap: () {
                        closeActions();
                        widget.onPin();
                      },
                    ),
                  ),
                  Expanded(
                    child: _SwipeAction(
                      key: Key('delete-conversation-${widget.item.id}'),
                      color: const Color(0xFFFF4D5E),
                      icon: Icons.delete_outline_rounded,
                      label: '删除',
                      onTap: () {
                        closeActions();
                        widget.onDelete();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(offset, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) {
              setState(() {
                offset = (offset + details.delta.dx).clamp(-actionWidth, 0);
              });
            },
            onHorizontalDragEnd: (details) {
              final open =
                  details.primaryVelocity != null &&
                      details.primaryVelocity! < -280 ||
                  offset < -actionWidth / 3;
              setState(() => offset = open ? -actionWidth : 0);
            },
            child: _ConversationTile(
              item: widget.item,
              onTap: offset == 0 ? widget.onTap : closeActions,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SwipeAction extends StatelessWidget {
  const _SwipeAction({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    child: InkWell(
      onTap: onTap,
      child: SizedBox.expand(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 21),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({required this.item, required this.onTap});
  final ConversationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: item.pinned ? const Color(0xFFF0F0F2) : Colors.white,
    child: InkWell(
      key: Key('conversation-${item.id}'),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Badge(
              isLabelVisible: item.unread > 0,
              label: Text(item.unread > 99 ? '99+' : '${item.unread}'),
              child: item.type == ConversationType.group
                  ? ChatAvatar.group(
                      key: Key('chat-avatar-group-${item.id}'),
                      members: conversationAvatarMembers(item),
                      radius: 25,
                    )
                  : ChatAvatar.person(
                      key: Key('chat-avatar-private-${item.id}'),
                      name: item.name,
                      radius: 25,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF858792),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.pinned) ...[
                      const Icon(
                        Icons.vertical_align_top_rounded,
                        size: 12,
                        color: Color(0xFF9A9CA5),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Text(
                      item.time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9A9CA5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (item.muted)
                  const Icon(
                    Icons.notifications_off_outlined,
                    size: 15,
                    color: Color(0xFF9A9CA5),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _MessagesBottomNavigation extends StatelessWidget {
  const _MessagesBottomNavigation({
    required this.onHome,
    required this.onVideo,
    required this.onUnavailable,
  });
  final VoidCallback onHome;
  final VoidCallback onVideo;
  final ValueChanged<String> onUnavailable;

  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: 2,
    onDestinationSelected: (index) {
      if (index == 0) {
        onHome();
      } else if (index == 1) {
        onVideo();
      } else if (index != 2) {
        onUnavailable(['首页', '视频', '消息', '我的'][index]);
      }
    },
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: '首页'),
      NavigationDestination(
        icon: Icon(Icons.play_circle_outline_rounded),
        label: '视频',
      ),
      NavigationDestination(icon: Icon(Icons.chat_bubble_rounded), label: '消息'),
      NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        label: '我的',
      ),
    ],
  );
}

class InteractionNotificationsScreen extends StatelessWidget {
  const InteractionNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => _NotificationListScreen(
    title: '互动消息',
    items: const [
      _Notice(
        icon: Icons.comment_rounded,
        title: 'Luna 评论了你的内容',
        detail: '这个思路很有启发，期待后续分享。',
        time: '10分钟前',
      ),
      _Notice(
        icon: Icons.reply_rounded,
        title: 'Kevin AI 回复了你',
        detail: '可以先从脚本生成和素材整理开始。',
        time: '1小时前',
      ),
      _Notice(
        icon: Icons.favorite_rounded,
        title: '小宇等 18 人赞了你的内容',
        detail: '社区产品如何把内容浏览变成真实关系？',
        time: '昨天',
      ),
    ],
  );
}

class FollowersNotificationsScreen extends StatefulWidget {
  const FollowersNotificationsScreen({super.key});

  @override
  State<FollowersNotificationsScreen> createState() =>
      _FollowersNotificationsScreenState();
}

class _FollowersNotificationsScreenState
    extends State<FollowersNotificationsScreen> {
  final Set<String> followed = {};

  @override
  Widget build(BuildContext context) {
    const users = ['Mia UX', '阿杰', 'Pixel Lab'];
    return Scaffold(
      appBar: AppBar(title: const Text('新关注')),
      body: ListView.separated(
        itemCount: users.length,
        separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final name = users[index];
          return ListTile(
            leading: CircleAvatar(child: Text(name.characters.first)),
            title: Text(name),
            subtitle: const Text('关注了你'),
            trailing: FilledButton.tonal(
              onPressed: () => setState(
                () => followed.contains(name)
                    ? followed.remove(name)
                    : followed.add(name),
              ),
              child: Text(followed.contains(name) ? '已关注' : '回关'),
            ),
          );
        },
      ),
    );
  }
}

class SystemNotificationsScreen extends StatelessWidget {
  const SystemNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) => _NotificationListScreen(
    title: '系统通知',
    items: const [
      _Notice(
        icon: Icons.verified_outlined,
        title: '内容审核通过',
        detail: '你发布的内容已通过审核并开始推荐。',
        time: '今天 09:30',
      ),
      _Notice(
        icon: Icons.campaign_outlined,
        title: '像素社区用户公约更新',
        detail: '新版社区规则将于下周生效。',
        time: '周四',
      ),
      _Notice(
        icon: Icons.warning_amber_rounded,
        title: '内容处理通知',
        detail: '部分内容因包含无关推广信息已降低推荐。',
        time: '周一',
      ),
    ],
  );
}

class _Notice {
  const _Notice({
    required this.icon,
    required this.title,
    required this.detail,
    required this.time,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String time;
}

class _NotificationListScreen extends StatelessWidget {
  const _NotificationListScreen({required this.title, required this.items});
  final String title;
  final List<_Notice> items;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 7,
          ),
          leading: CircleAvatar(child: Icon(item.icon)),
          title: Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            item.detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Text(
            item.time,
            style: const TextStyle(fontSize: 10, color: Color(0xFF9A9CA5)),
          ),
          onTap: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已打开对应内容'))),
        );
      },
    ),
  );
}

class MessageRequestsScreen extends StatefulWidget {
  const MessageRequestsScreen({super.key});

  @override
  State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> {
  final List<String> requests = ['摄影师小北', 'Growth Lab'];

  void remove(String name, String result) {
    setState(() => requests.remove(name));
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('已$result $name 的消息请求')));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('消息请求')),
    body: requests.isEmpty
        ? const Center(child: Text('暂无消息请求'))
        : ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final name = requests[index];
              return Card(
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(name.characters.first),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: const Text('你好，看了你的内容，想和你交流一下。'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => remove(name, value),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: '举报', child: Text('举报')),
                            PopupMenuItem(value: '拉黑', child: Text('拉黑')),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => remove(name, '拒绝'),
                            child: const Text('拒绝'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: () => remove(name, '接受'),
                            child: const Text('接受'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}
