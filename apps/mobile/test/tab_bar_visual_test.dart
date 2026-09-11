import 'dart:io';

import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    Future<ByteData> loadFont(String path) async {
      final bytes = await File(path).readAsBytes();
      return ByteData.sublistView(bytes);
    }

    await (FontLoader(
      'VisualQaFont',
    )..addFont(loadFont('/Users/mark/Library/Fonts/msyhbd.ttf'))).load();
    await (FontLoader('MaterialIcons')..addFont(
          loadFont(
            '/Users/mark/development/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ),
        ))
        .load();
  });

  testWidgets('底部玻璃标签栏视觉快照', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'VisualQaFont'),
        home: HomeScreen(session: AuthSession(AuthApi())),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byKey(const Key('ios-glass-tab-bar')),
      matchesGoldenFile('goldens/ios_glass_tab_bar.png'),
    );
  });
}
