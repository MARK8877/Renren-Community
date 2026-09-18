import 'package:creatorhub_app/src/screens/video_feed_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completed short drama playback requests a fresh controller', () {
    expect(
      shouldRefreshShortDramaController(isShortDrama: true, isCompleted: true),
      isTrue,
    );
    expect(
      shouldRefreshShortDramaController(isShortDrama: false, isCompleted: true),
      isFalse,
    );
    expect(
      shouldDisposeShortDramaController(isShortDrama: true, isCurrent: false),
      isTrue,
    );
  });
}
