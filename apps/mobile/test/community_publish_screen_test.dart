import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/community_publish_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('发布动态提供图片入口并支持预览和移除', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPublishScreen(session: AuthSession(AuthApi())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('publish-add-image')), findsOneWidget);
    await tester.tap(find.byKey(const Key('publish-add-image')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publish-image-picker')), findsOneWidget);
    expect(find.byKey(const Key('publish-image-option-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('publish-image-option-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publish-selected-image-0')), findsOneWidget);

    await tester.tap(find.byKey(const Key('publish-remove-image-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publish-selected-image-0')), findsNothing);
  });

  testWidgets('发布动态支持 @ 好友和表情输入', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPublishScreen(session: AuthSession(AuthApi())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('publish-mention')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publish-mention-picker')), findsOneWidget);
    await tester.tap(find.byKey(const Key('publish-mention-option-0')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('publish-content')))
          .controller!
          .text,
      '@林木设计 ',
    );

    await tester.tap(find.byKey(const Key('publish-emoji')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('publish-emoji-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('publish-emoji-😀')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('publish-content')))
          .controller!
          .text,
      '@林木设计 😀',
    );
  });

  testWidgets('点击发布页空白区域可以收起键盘', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CommunityPublishScreen(session: AuthSession(AuthApi())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('publish-content')));
    await tester.pump();
    final contentField = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const Key('publish-content')),
        matching: find.byType(EditableText),
      ),
    );
    expect(contentField.focusNode.hasFocus, isTrue);

    await tester.tap(find.text('选择话题'));
    await tester.pump();
    expect(contentField.focusNode.hasFocus, isFalse);
  });
}
