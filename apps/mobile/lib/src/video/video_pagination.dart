import 'video_api.dart';

typedef VideoPageFetcher =
    Future<List<PlatformVideoData>> Function(int page, int pageSize);

class VideoPagination {
  VideoPagination({required this.pageSize, required this.fetchPage});

  final int pageSize;
  final VideoPageFetcher fetchPage;

  int _nextPage = 1;
  Future<List<PlatformVideoData>>? _pending;
  final _seen = <String>{};

  bool hasMore = true;

  Future<List<PlatformVideoData>> loadNext() {
    if (!hasMore) return Future<List<PlatformVideoData>>.value(const []);
    final pending = _pending;
    if (pending != null) return pending;

    late final Future<List<PlatformVideoData>> request;
    request = _loadPage().whenComplete(() {
      if (identical(_pending, request)) _pending = null;
    });
    _pending = request;
    return request;
  }

  Future<List<PlatformVideoData>> _loadPage() async {
    final page = _nextPage;
    final items = await fetchPage(page, pageSize);
    _nextPage += 1;
    if (items.length < pageSize) hasMore = false;

    final unique = <PlatformVideoData>[];
    for (final item in items) {
      final key = '${item.platform}:${item.externalId}';
      if (_seen.add(key)) unique.add(item);
    }
    return unique;
  }
}
