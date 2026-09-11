import 'package:creatorhub_app/src/video/video_api.dart';
import 'package:creatorhub_app/src/video/video_pagination.dart';
import 'package:flutter_test/flutter_test.dart';

PlatformVideoData video(String id) => PlatformVideoData(
  id: int.parse(id),
  platform: 'pexels',
  externalId: id,
  title: '视频 $id',
  playUrl: 'https://example.com/$id.mp4',
  likeCount: 0,
  commentCount: 0,
  shareCount: 0,
);

void main() {
  test('分页追加时去重，并在短页后停止继续请求', () async {
    final requests = <int>[];
    final pager = VideoPagination(
      pageSize: 2,
      fetchPage: (page, _) async {
        requests.add(page);
        if (page == 1) return [video('1'), video('2')];
        if (page == 2) return [video('2'), video('3')];
        return [video('4')];
      },
    );

    expect((await pager.loadNext()).map((item) => item.externalId), ['1', '2']);
    expect((await pager.loadNext()).map((item) => item.externalId), ['3']);
    expect((await pager.loadNext()).map((item) => item.externalId), ['4']);
    expect(await pager.loadNext(), isEmpty);
    expect(requests, [1, 2, 3]);
    expect(pager.hasMore, isFalse);
  });

  test('并发触发下一页时只发出一个请求，失败后允许重试', () async {
    var requestCount = 0;
    var shouldFail = true;
    final pager = VideoPagination(
      pageSize: 20,
      fetchPage: (_, _) async {
        requestCount += 1;
        await Future<void>.delayed(const Duration(milliseconds: 1));
        if (shouldFail) {
          shouldFail = false;
          throw StateError('temporary failure');
        }
        return [video('1')];
      },
    );

    await expectLater(
      Future.wait([pager.loadNext(), pager.loadNext()]),
      throwsA(isA<StateError>()),
    );
    expect(requestCount, 1);
    expect((await pager.loadNext()).map((item) => item.externalId), ['1']);
    expect(requestCount, 2);
  });
}
