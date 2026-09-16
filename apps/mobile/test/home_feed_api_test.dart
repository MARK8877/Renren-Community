import 'dart:convert';

import 'package:creatorhub_app/src/home/home_feed_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('读取首页外部动态并保留来源链接', () async {
    final posts = await HomeFeedApi(
      client: _HomeFeedClient(),
      baseUrl: 'http://test.local',
    ).list('test-token');

    expect(posts, hasLength(1));
    expect(posts.single.author, 'Product School');
    expect(posts.single.content, 'Agentic Architecture');
    expect(
      posts.single.url,
      'https://productschool.com/blog/artificial-intelligence/agentic-architecture',
    );
  });
}

class _HomeFeedClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(
    http.BaseRequest request,
  ) async => http.StreamedResponse(
    Stream<List<int>>.fromIterable([
      utf8.encode(
        jsonEncode({
          'code': 0,
          'message': 'ok',
          'data': [
            {
              'id': 1,
              'source': 'productschool',
              'externalId': 'artificial-intelligence/agentic-architecture',
              'author': 'Product School',
              'role': 'Artificial Intelligence',
              'content': 'Agentic Architecture',
              'tags': ['#Artificial Intelligence'],
              'url':
                  'https://productschool.com/blog/artificial-intelligence/agentic-architecture',
              'scrapedAt': '2026-09-15T08:00:00Z',
            },
          ],
        }),
      ),
    ]),
    200,
    request: request,
    headers: const {'content-type': 'application/json'},
  );
}
