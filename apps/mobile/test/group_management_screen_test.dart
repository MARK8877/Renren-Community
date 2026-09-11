import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/chat/chat_api.dart';
import 'package:creatorhub_app/src/screens/group_management_screen.dart';
import 'package:creatorhub_app/src/screens/transfer_group_owner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('群管理页展示群资料和成员管理入口', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GroupManagementScreen(
          session: AuthSession(AuthApi()),
          conversationId: 'local-group-1',
          groupName: '创作者共创群',
          memberCount: '1',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group-management-screen')), findsOneWidget);
    expect(
      find.byKey(const Key('group-management-profile-hero')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('group-management-section-profile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('group-management-section-permissions')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('management-avatar-picker')), findsOneWidget);
    expect(find.byKey(const Key('management-announcement')), findsOneWidget);
    expect(find.byKey(const Key('management-save-profile')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byKey(const Key('management-save-profile')),
      ),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pump();
    expect(
      find.byKey(const Key('group-management-section-members')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('management-member-list')), findsOneWidget);
    expect(find.byKey(const Key('member-actions-2')), findsOneWidget);
    expect(find.byKey(const Key('leave-group')), findsOneWidget);
  });

  testWidgets('群组接口解析异常时点击群组不会崩溃', (tester) async {
    SharedPreferences.setMockInitialValues({
      AuthSession.accessTokenKey: 'test-token',
      AuthSession.nicknameKey: '测试用户',
    });
    final session = AuthSession(AuthApi());
    await session.restore();

    await tester.pumpWidget(
      MaterialApp(
        home: GroupManagementScreen(
          session: session,
          conversationId: 'group-ai',
          groupName: 'AI 视频创作者交流群',
          memberCount: '2,856',
          chatApi: _MalformedGroupApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('group-management-screen')), findsOneWidget);
    expect(find.text('群组数据加载失败，请稍后重试'), findsOneWidget);
  });

  testWidgets('群主可从群管理页进入转让群主页面并选择成员', (tester) async {
    final session = AuthSession(AuthApi());
    await tester.pumpWidget(
      MaterialApp(
        home: GroupManagementScreen(
          session: session,
          conversationId: 'group-ai',
          groupName: 'AI 视频创作者交流群',
          memberCount: '3',
          chatApi: _TransferOwnerApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -360));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('transfer-owner-entry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer-group-owner-screen')), findsOneWidget);
    expect(find.text('选择新群主'), findsOneWidget);
    expect(find.byKey(const Key('transfer-owner-member-2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('transfer-owner-member-2')));
    await tester.pump();
    expect(find.byKey(const Key('confirm-transfer-owner')), findsOneWidget);
  });

  testWidgets('没有可转让成员时展示明确空状态', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TransferGroupOwnerScreen(
          session: AuthSession(AuthApi()),
          conversationId: 'group-ai',
          members: const [
            GroupMemberData(userId: 1, nickname: '我', role: 'owner'),
          ],
          chatApi: ChatApi(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('transfer-owner-empty-state')), findsOneWidget);
    expect(find.text('暂无可转让成员'), findsOneWidget);
  });
}

class _MalformedGroupApi extends ChatApi {
  @override
  Future<GroupDetailsData> groupDetails(String token, String conversationId) =>
      throw const FormatException('invalid group response');
}

class _TransferOwnerApi extends ChatApi {
  @override
  Future<GroupDetailsData> groupDetails(String token, String conversationId) =>
      Future.value(
        const GroupDetailsData(
          id: 'group-ai',
          name: 'AI 视频创作者交流群',
          ownerUserId: 1,
          avatarAssetKey: '',
          announcement: '',
          joinMode: 'direct',
          memberInviteEnabled: true,
          role: 'owner',
        ),
      );

  @override
  Future<List<GroupMemberData>> groupMembers(
    String token,
    String conversationId,
  ) => Future.value(const [
    GroupMemberData(userId: 1, nickname: '我', role: 'owner'),
    GroupMemberData(userId: 2, nickname: 'Luna', role: 'admin'),
    GroupMemberData(userId: 3, nickname: '小宇', role: 'member'),
  ]);

  @override
  Future<List<JoinRequestData>> joinRequests(
    String token,
    String conversationId,
  ) => Future.value(const []);
}
