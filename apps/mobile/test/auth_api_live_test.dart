import 'package:creatorhub_app/src/auth/auth_api.dart';
import 'package:flutter_test/flutter_test.dart';

const liveApiBaseUrl = String.fromEnvironment('LIVE_API_BASE_URL');
const liveTestIdentifier = String.fromEnvironment('LIVE_TEST_IDENTIFIER');
const liveTestPassword = String.fromEnvironment('LIVE_TEST_PASSWORD');

void main() {
  test(
    '测试账号可调用真实登录 API',
    () async {
      expect(
        liveTestIdentifier,
        isNotEmpty,
        reason: '启用真实 API 测试时必须设置 LIVE_TEST_IDENTIFIER',
      );
      expect(
        liveTestPassword,
        isNotEmpty,
        reason: '启用真实 API 测试时必须设置 LIVE_TEST_PASSWORD',
      );

      final result = await AuthApi(
        baseUrl: liveApiBaseUrl,
      ).login(liveTestIdentifier, liveTestPassword);

      expect(result.token, isNotEmpty);
      expect(result.nickname, isNotEmpty);
    },
    skip: liveApiBaseUrl.isEmpty ? '设置 LIVE_API_BASE_URL 后才运行真实 API 测试' : false,
  );
}
