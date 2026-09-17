import 'package:creatorhub_app/src/shortdrama/short_drama_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('parses short drama list and first episode', () async {
    final client = _QueueClient(
      (request) async => http.Response(
        '''{"code":0,"message":"ok","data":[{"id":1,"name":"西游散伙人","totalEpisodes":66,"episodes":[{"episode":1,"title":"第1集.mp4","duration":120,"m3u8url":"https://cdn.example/1.m3u8"}]}]}''',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final api = ShortDramaApi(client: client, baseUrl: 'http://api.test');
    final dramas = await api.list('token');
    expect(dramas.single.name, '西游散伙人');
    expect(dramas.single.episodes.single.m3u8Url, 'https://cdn.example/1.m3u8');
    expect(client.requests.single.url.path, '/api/v1/short-dramas');
  });

  test('requests refreshed episode playback URL', () async {
    final client = _QueueClient(
      (request) async => http.Response(
        '''{"code":0,"message":"ok","data":{"url":"https://cdn.example/2.m3u8","duration":90}}''',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    );
    final api = ShortDramaApi(client: client, baseUrl: 'http://api.test');
    final playback = await api.playUrl('token', 7, 2);
    expect(playback.url, 'https://cdn.example/2.m3u8');
    expect(client.requests.single.headers['Authorization'], 'Bearer token');
    expect(
      client.requests.single.url.path,
      '/api/v1/short-dramas/7/episodes/2/play-url',
    );
  });
}

class _QueueClient extends http.BaseClient {
  _QueueClient(this.handler);
  final Future<http.Response> Function(http.BaseRequest) handler;
  final requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    final response = await handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
