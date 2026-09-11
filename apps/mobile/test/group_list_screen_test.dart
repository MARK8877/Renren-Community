import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/group_list_screen.dart';
import 'package:creatorhub_app/src/screens/messages_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('群组列表展示群头像、成员数和统一管理入口', (tester) async {
    final session = AuthSession(AuthApi());
    final groups = [
      ConversationItem(
        id: 'group-ai',
        name: 'AI 视频创作者交流群',
        message: '今晚分享完整工作流',
        time: '12:36',
        updatedAt: DateTime(2026, 9, 8, 12, 36),
        type: ConversationType.group,
        memberCount: '2,856',
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: GroupListScreen(session: session, groups: groups),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('groups-list-screen')), findsOneWidget);
    expect(find.text('AI 视频创作者交流群'), findsOneWidget);
    expect(find.text('2,856 位成员'), findsOneWidget);
    expect(find.byKey(const Key('group-list-create')), findsOneWidget);
  });
}
