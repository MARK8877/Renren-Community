import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/auth/auth_session.dart';
import 'package:creatorhub_app/src/screens/video_feed_screen.dart';
import 'package:creatorhub_app/src/shortdrama/short_drama_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('短剧页面展示当前剧集信息并使用独立上下滑动容器', (tester) async {
    final drama = ShortDramaData(
      id: 1,
      name: '测试短剧',
      totalEpisodes: 2,
      episodes: const [
        ShortDramaEpisodeData(
          episode: 1,
          title: '第1集.mp4',
          m3u8Url: 'https://cdn.example/1.m3u8',
        ),
        ShortDramaEpisodeData(
          episode: 2,
          title: '第2集.mp4',
          m3u8Url: 'https://cdn.example/2.m3u8',
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ShortDramaFeedScreen(
          session: AuthSession(AuthApi()),
          drama: drama,
          api: ShortDramaApi(baseUrl: 'http://api.test'),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('short-drama-vertical-feed')), findsOneWidget);
    expect(
      find.byKey(const Key('short-drama-episode-progress')),
      findsOneWidget,
    );
    expect(find.text('测试短剧'), findsWidgets);
    expect(find.text('第 1 集 / 共 2 集'), findsOneWidget);
    expect(find.text('第1集.mp4'), findsNothing);
  });
}
