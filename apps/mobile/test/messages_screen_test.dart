import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/messages_screen.dart';
import 'package:creatorhub_app/src/widgets/chat_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpMessages(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(home: MessagesScreen(session: AuthSession(AuthApi()))),
    );
  }

  test('未知群聊也会生成多个成员头像', () {
    final members = conversationAvatarMembers(
      ConversationItem(
        id: 'public-chat',
        name: '公共群',
        message: '',
        time: '',
        updatedAt: DateTime(2026, 9, 9),
        type: ConversationType.group,
      ),
    );

    expect(members.length, greaterThanOrEqualTo(4));
    expect(members.toSet().length, equals(members.length));
  });

  testWidgets('私聊和群聊合并显示，不再展示分类菜单', (tester) async {
    await pumpMessages(tester);

    expect(find.byKey(const Key('unified-conversation-list')), findsOneWidget);
    expect(find.byKey(const Key('entry-interactions')), findsNothing);
    expect(find.byType(SegmentedButton<String>), findsNothing);
    expect(find.text('AI 视频创作者交流群'), findsOneWidget);
    expect(find.text('Luna Design'), findsOneWidget);
  });

  testWidgets('会话列表使用人物头像和多成员群组拼图头像', (tester) async {
    await pumpMessages(tester);

    expect(find.byKey(const Key('chat-avatar-private-luna')), findsOneWidget);
    expect(find.byKey(const Key('chat-avatar-group-group-ai')), findsOneWidget);
    final groupAvatar = tester.widget<ChatAvatar>(
      find.byKey(const Key('chat-avatar-group-group-ai')),
    );
    expect(groupAvatar.isGroup, isTrue);
    expect(groupAvatar.members, ['Kevin AI', 'Luna', '小宇', '阿杰']);
    expect(
      find.descendant(
        of: find.byKey(const Key('chat-avatar-group-group-ai')),
        matching: find.byType(ClipRRect),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('chat-avatar-private-luna')),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('chat-avatar-group-group-ai')),
        matching: find.byType(Image),
      ),
      findsNWidgets(4),
    );
  });

  testWidgets('联系人位于消息标题右侧并可搜索后发起私聊', (tester) async {
    await pumpMessages(tester);

    final messagesTab = find.byKey(const Key('messages-section-tab'));
    final contactsTab = find.byKey(const Key('contacts-section-tab'));
    expect(messagesTab, findsOneWidget);
    expect(contactsTab, findsOneWidget);
    expect(
      tester.getCenter(contactsTab).dx,
      greaterThan(tester.getCenter(messagesTab).dx),
    );

    await tester.tap(contactsTab);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('contacts-panel')), findsOneWidget);
    expect(find.byKey(const Key('contacts-list')), findsOneWidget);
    expect(find.byKey(const Key('contact-luna')), findsOneWidget);
    expect(find.byKey(const Key('contact-xiaoyu')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('contacts-search')), '小宇');
    await tester.pump();
    expect(find.byKey(const Key('contact-xiaoyu')), findsOneWidget);
    expect(find.byKey(const Key('contact-luna')), findsNothing);

    await tester.tap(find.byKey(const Key('contact-xiaoyu')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('private-input')), findsOneWidget);
    expect(find.text('小宇'), findsWidgets);
  });

  testWidgets('消息和联系人支持左右滑动切换', (tester) async {
    await pumpMessages(tester);

    await tester.dragFrom(const Offset(360, 650), const Offset(-330, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contacts-list')), findsOneWidget);
    expect(find.byKey(const Key('mark-all-read')), findsNothing);

    await tester.dragFrom(const Offset(30, 650), const Offset(330, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('unified-conversation-list')), findsOneWidget);
    expect(find.byKey(const Key('mark-all-read')), findsNothing);
  });

  testWidgets('联系人页可进入添加联系人和新的好友', (tester) async {
    await pumpMessages(tester);

    await tester.tap(find.byKey(const Key('contacts-section-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-contact-entry')), findsOneWidget);
    expect(find.byKey(const Key('new-friends-entry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('add-contact-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-contact-screen')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('add-contact-search')), 'Luna');
    await tester.tap(find.byKey(const Key('add-contact-search-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('add-contact-results')), findsOneWidget);
    expect(find.text('已添加'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-friends-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('friend-requests-screen')), findsOneWidget);
    expect(find.text('暂无新的好友申请'), findsOneWidget);
  });

  testWidgets('联系人页可进入群组列表并打开统一群管理页', (tester) async {
    await pumpMessages(tester);

    await tester.tap(find.byKey(const Key('contacts-section-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('contacts-groups-entry')), findsOneWidget);

    await tester.tap(find.byKey(const Key('contacts-groups-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('groups-list-screen')), findsOneWidget);
    expect(find.byKey(const Key('group-list-group-ai')), findsOneWidget);

    await tester.tap(find.byKey(const Key('group-list-group-ai')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('group-management-screen')), findsOneWidget);
  });

  testWidgets('会话按最新消息时间倒序排列且移除全部已读', (tester) async {
    await pumpMessages(tester);

    final groupAiY = tester
        .getTopLeft(find.byKey(const Key('conversation-group-ai')))
        .dy;
    final lunaY = tester
        .getTopLeft(find.byKey(const Key('conversation-luna')))
        .dy;
    final productY = tester
        .getTopLeft(find.byKey(const Key('conversation-group-product')))
        .dy;
    final xiaoyuY = tester
        .getTopLeft(find.byKey(const Key('conversation-xiaoyu')))
        .dy;
    expect(groupAiY, lessThan(lunaY));
    expect(lunaY, lessThan(productY));
    expect(productY, lessThan(xiaoyuY));

    expect(find.byKey(const Key('mark-all-read')), findsNothing);
    expect(find.text('全部已读'), findsNothing);
  });

  testWidgets('消息页综合入口包含建群、添加好友和好友申请', (tester) async {
    await pumpMessages(tester);

    final composeMenu = tester.widget<PopupMenuButton<String>>(
      find.byKey(const Key('messages-compose-actions')),
    );
    expect(composeMenu.position, PopupMenuPosition.under);
    expect(composeMenu.offset, const Offset(0, 8));
    expect(composeMenu.color, const Color(0xFF6256E8));
    await tester.tap(find.byKey(const Key('messages-compose-actions')));
    await tester.pumpAndSettle();
    final groupItem = tester.widget<PopupMenuItem<String>>(
      find.byKey(const Key('compose-start-group')),
    );
    expect(groupItem.textStyle?.color, Colors.black);
    expect(find.text('发起群聊'), findsOneWidget);
    expect(find.text('添加好友'), findsOneWidget);
    expect(find.text('新的好友'), findsOneWidget);

    await tester.tap(find.text('发起群聊'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('create-group-screen')), findsOneWidget);
  });

  testWidgets('左滑会话可置顶，置顶会话优先显示', (tester) async {
    await pumpMessages(tester);

    await tester.drag(
      find.byKey(const Key('conversation-xiaoyu')),
      const Offset(-190, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pin-conversation-xiaoyu')));
    await tester.pumpAndSettle();

    final xiaoyuY = tester
        .getTopLeft(find.byKey(const Key('conversation-xiaoyu')))
        .dy;
    final groupAiY = tester
        .getTopLeft(find.byKey(const Key('conversation-group-ai')))
        .dy;
    expect(xiaoyuY, lessThan(groupAiY));
  });

  testWidgets('左滑会话可删除且不再使用长按菜单', (tester) async {
    await pumpMessages(tester);

    await tester.drag(
      find.byKey(const Key('conversation-group-ai')),
      const Offset(-190, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-conversation-group-ai')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('conversation-group-ai')), findsNothing);
    expect(find.text('已删除会话'), findsOneWidget);
  });

  testWidgets('群聊会话进入现有群聊页', (tester) async {
    await pumpMessages(tester);

    await tester.tap(find.byKey(const Key('conversation-group-ai')));
    await tester.pumpAndSettle();
    expect(find.text('群公告：请遵守群规，友善交流，共同成长。'), findsOneWidget);
    expect(find.byKey(const Key('chat-input')), findsOneWidget);
  });

  testWidgets('消息页底部视频入口进入视频流', (tester) async {
    await pumpMessages(tester);

    await tester.tap(find.text('视频'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byKey(const Key('vertical-video-feed')), findsOneWidget);
  });

  testWidgets('私聊支持发送消息并拉黑用户', (tester) async {
    await pumpMessages(tester);

    await tester.tap(find.byKey(const Key('conversation-luna')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('private-input')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('private-input')), '你好');
    await tester.tap(find.byKey(const Key('private-send')));
    await tester.pumpAndSettle();
    expect(find.text('你好'), findsOneWidget);

    await tester.tap(find.byKey(const Key('private-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('block-user')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('blocked-notice')), findsOneWidget);
    final input = tester.widget<TextField>(
      find.byKey(const Key('private-input')),
    );
    expect(input.enabled, isFalse);
  });

  testWidgets('私聊消息显示好友头像、昵称和自己的头像', (tester) async {
    await pumpMessages(tester);

    await tester.tap(find.byKey(const Key('conversation-luna')));
    await tester.pumpAndSettle();

    final friendAvatar = find.byKey(const Key('private-friend-avatar-1'));
    final friendNickname = find.byKey(const Key('private-friend-nickname-1'));
    final ownAvatar = find.byKey(const Key('private-own-avatar-2'));
    expect(friendAvatar, findsOneWidget);
    expect(friendNickname, findsOneWidget);
    expect(ownAvatar, findsOneWidget);
    expect(tester.widget<Text>(friendNickname).data, 'Luna Design');

    expect(
      tester.getCenter(friendAvatar).dx,
      lessThan(tester.getCenter(find.byKey(const Key('private-message-1'))).dx),
    );
    expect(
      tester.getCenter(ownAvatar).dx,
      greaterThan(
        tester.getCenter(find.byKey(const Key('private-message-2'))).dx,
      ),
    );
  });

  testWidgets('私聊输入区同步群聊样式并支持表情和图片', (tester) async {
    await pumpMessages(tester);

    await tester.tap(find.byKey(const Key('conversation-luna')));
    await tester.pumpAndSettle();

    final input = tester.widget<TextField>(
      find.byKey(const Key('private-input')),
    );
    final decoration = input.decoration!;
    expect(input.minLines, 1);
    expect(input.maxLines, 4);
    expect(input.textInputAction, TextInputAction.newline);
    expect(decoration.filled, isTrue);
    expect(decoration.fillColor, const Color(0xFFF3F3F7));

    await tester.tap(find.byKey(const Key('private-emoji-button')));
    await tester.pump();
    expect(find.byKey(const Key('private-emoji-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('private-emoji-😀')));
    await tester.tap(find.byKey(const Key('private-send')));
    await tester.pumpAndSettle();
    expect(find.text('😀'), findsOneWidget);
    expect(find.byKey(const Key('private-emoji-panel')), findsNothing);

    await tester.tap(find.byKey(const Key('private-attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('private-send-image')));
    await tester.pumpAndSettle();
    expect(find.text('我分享了一张图片'), findsOneWidget);
  });
}
