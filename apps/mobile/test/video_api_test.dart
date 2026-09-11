import 'dart:convert';

import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/video/video_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('视频接口解析标准字段并带上鉴权请求', () async {
    final client = _VideoClient();
    final api = VideoApi(
      client: client,
      authApi: AuthApi(baseUrl: 'http://test.local'),
    );

    final videos = await api.list('token');

    expect(videos.single.title, '热门视频');
    expect(videos.single.playUrl, 'https://example.com/video.mp4');
    expect(videos.single.likeCount, 1_500_000);
    expect(client.authorization, 'Bearer token');
    expect(client.path, '/api/v1/videos');
    expect(client.query, {'page': '1', 'pageSize': '20'});
  });
}

class _VideoClient extends http.BaseClient {
  String? authorization;
  String? path;
  Map<String, String>? query;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    authorization = request.headers['Authorization'];
    path = request.url.path;
    query = request.url.queryParameters;
    const body =
        '''{"code":0,"message":"ok","data":[{"id":1,"platform":"youtube","externalId":"yt-1","title":"热门视频","playUrl":"https://example.com/video.mp4","likeCount":1500000,"commentCount":8000,"shareCount":1200,"publishedAt":"2026-09-01T12:30:00Z","scrapedAt":"2026-09-02T12:30:00Z"}]}''';
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([utf8.encode(body)]),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}
