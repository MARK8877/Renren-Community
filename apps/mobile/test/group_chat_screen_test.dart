import 'package:creatorhub_app/src/screens/group_chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpChat(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: GroupChatScreen(
          groupName: 'AI 视频创作者交流群',
          memberCount: '2,856',
          currentUser: '测试用户',
        ),
      ),
    );
  }

  testWidgets('群聊页展示基础结构并加载历史消息', (tester) async {
    await pumpChat(tester);

    expect(find.text('AI 视频创作者交流群'), findsOneWidget);
    expect(find.text('以下是未读消息'), findsOneWidget);
    expect(find.text('发送消息…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('load-history')));
    await tester.pumpAndSettle();
    expect(find.text('大家常用哪些剪辑工具？'), findsOneWidget);
  });

  testWidgets('发送失败消息可以重试', (tester) async {
    await pumpChat(tester);

    await tester.drag(
      find.byKey(const Key('message-list')),
      const Offset(0, -500),
    );
    await tester.pumpAndSettle();
    expect(find.text('有人整理过完整的工具清单吗？'), findsOneWidget);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);
    await tester.tap(find.byIcon(Icons.error_rounded));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.error_rounded), findsNothing);
  });

  testWidgets('禁言状态显示时间并禁止发送', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: GroupChatScreen(
          groupName: 'AI 视频创作者交流群',
          memberCount: '2,856',
          currentUser: '测试用户',
          mutedUntil: '今天 18:00',
        ),
      ),
    );

    expect(find.byKey(const Key('muted-notice')), findsOneWidget);
    expect(find.text('你已被禁言，解除时间：今天 18:00'), findsOneWidget);
    final input = tester.widget<TextField>(find.byKey(const Key('chat-input')));
    expect(input.enabled, isFalse);
  });

  testWidgets('可以发送文字、表情和图片消息', (tester) async {
    await pumpChat(tester);

    await tester.enterText(find.byKey(const Key('chat-input')), '大家好');
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();
    expect(find.text('大家好'), findsOneWidget);
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('emoji-button')));
    await tester.pump();
    expect(find.byKey(const Key('emoji-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('emoji-😀')));
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();
    expect(find.text('😀'), findsOneWidget);

    await tester.tap(find.byKey(const Key('attachment-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('send-image')));
    await tester.pumpAndSettle();
    expect(find.text('我分享了一张图片'), findsOneWidget);
  });

  testWidgets('支持回复和撤回消息', (tester) async {
    await pumpChat(tester);

    final original = find.text('欢迎大家加入！这里可以交流 AI 视频创作流程。');
    await tester.longPress(original);
    await tester.pumpAndSettle();
    await tester.tap(find.text('回复'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('reply-preview')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('chat-input')), '收到');
    await tester.tap(find.byKey(const Key('send-button')));
    await tester.pumpAndSettle();
    expect(find.text('收到'), findsOneWidget);

    await tester.longPress(find.text('收到'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('撤回'));
    await tester.pumpAndSettle();
    expect(find.text('你撤回了一条消息'), findsOneWidget);
  });

  testWidgets('可进入群资料并操作邀请和退出确认', (tester) async {
    await pumpChat(tester);

    await tester.tap(find.byKey(const Key('group-info-entry')));
    await tester.pumpAndSettle();
    expect(find.text('群资料'), findsOneWidget);
    expect(find.text('群规则'), findsOneWidget);

    await tester.tap(find.byKey(const Key('invite-member')));
    await tester.pump();
    expect(find.text('邀请链接已生成'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const Key('exit-group')));
    await tester.tap(find.byKey(const Key('exit-group')));
    await tester.pumpAndSettle();
    expect(find.text('退出群聊？'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('群资料'), findsOneWidget);
  });
}
