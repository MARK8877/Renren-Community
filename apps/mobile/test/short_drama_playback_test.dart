import 'package:creatorhub_app/src/screens/video_feed_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('播放结束时只切换到下一集，最后一集不再前进', () {
    expect(
      shortDramaNextEpisodeIndex(
        currentIndex: 0,
        totalEpisodes: 3,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 10),
        isPlaying: false,
      ),
      1,
    );
    expect(
      shortDramaNextEpisodeIndex(
        currentIndex: 2,
        totalEpisodes: 3,
        position: const Duration(seconds: 10),
        duration: const Duration(seconds: 10),
        isPlaying: false,
      ),
      isNull,
    );
    expect(
      shortDramaNextEpisodeIndex(
        currentIndex: 0,
        totalEpisodes: 3,
        position: const Duration(seconds: 9),
        duration: const Duration(seconds: 10),
        isPlaying: true,
      ),
      isNull,
    );
  });
}
