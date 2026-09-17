import 'package:creatorhub_app/src/screens/video_feed_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('视频主页短剧描述不显示集数文件名，普通视频仍保留描述', () {
    expect(
      shortDramaVideoDescription(isShortDrama: true, caption: '第1集.mp4'),
      isNull,
    );
    expect(
      shortDramaVideoDescription(isShortDrama: false, caption: '普通视频描述'),
      '普通视频描述',
    );
  });
}
