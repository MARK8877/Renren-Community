import 'dart:async';

import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:creatorhub_app/src/chat/chat_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  test('入群申请接口返回 null 数据时按空列表处理', () async {
    final api = ChatApi(
      client: _NullJoinRequestsClient(),
      authApi: AuthApi(baseUrl: 'http://test.local'),
    );

    expect(await api.joinRequests('token', 'group-ai'), isEmpty);
  });

  test('退出群聊使用专用 DELETE 接口', () async {
    final client = _LeaveGroupClient();
    final api = ChatApi(
      client: client,
      authApi: AuthApi(baseUrl: 'http://test.local'),
    );

    await api.leaveGroup('token', 'group-ai');

    expect(client.method, 'DELETE');
    expect(client.path, '/api/v1/conversations/group-ai/leave');
  });

  test('转让群主使用 PATCH owner 接口并提交目标成员', () async {
    final client = _TransferOwnerClient();
    final api = ChatApi(
      client: client,
      authApi: AuthApi(baseUrl: 'http://test.local'),
    );

    await api.transferGroupOwner('token', 'group-ai', 42);

    expect(client.method, 'PATCH');
    expect(client.path, '/api/v1/conversations/group-ai/owner');
    expect(client.body, contains('"userId":42'));
  });
}

class _NullJoinRequestsClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = '{"code":0,"message":"ok","data":null}';
    final stream = Stream<List<int>>.fromIterable([body.codeUnits]);
    return http.StreamedResponse(
      stream,
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }
}

class _LeaveGroupClient extends http.BaseClient {
  String? method;
  String? path;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    method = request.method;
    path = request.url.path;
    final stream = Stream<List<int>>.fromIterable([
      '{"code":0,"message":"ok","data":null}'.codeUnits,
    ]);
    return http.StreamedResponse(stream, 200, request: request);
  }
}

class _TransferOwnerClient extends http.BaseClient {
  String? method;
  String? path;
  String? body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    method = request.method;
    path = request.url.path;
    body = request is http.Request ? request.body : null;
    final stream = Stream<List<int>>.fromIterable([
      '{"code":0,"message":"ok","data":null}'.codeUnits,
    ]);
    return http.StreamedResponse(stream, 200, request: request);
  }
}
