import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/create_group_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('建群页校验名称并展示群管理初始设置', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: CreateGroupScreen(session: AuthSession(AuthApi()))),
    );

    expect(find.byKey(const Key('create-group-screen')), findsOneWidget);
    expect(find.byKey(const Key('group-avatar-picker')), findsOneWidget);
    expect(find.byKey(const Key('group-announcement')), findsOneWidget);
    expect(find.byKey(const Key('group-join-mode')), findsOneWidget);
    expect(find.byKey(const Key('group-member-invite')), findsOneWidget);

    await tester.enterText(find.byKey(const Key('group-name')), 'A');
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('create-group-submit')))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byKey(const Key('group-name')), '创作者共创群');
    await tester.pump();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('create-group-submit')))
          .onPressed,
      isNotNull,
    );
  });
}
