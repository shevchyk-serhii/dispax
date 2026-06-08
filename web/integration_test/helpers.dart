import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:dispax/modules/core/services/api_client.dart';

export 'test_accounts.dart';

/// Port of the local TestApplication. Defaults to 8080; override with
/// `--dart-define=TEST_SERVER_PORT=8090` to run alongside a dev server.
const int kTestServerPort = int.fromEnvironment(
  'TEST_SERVER_PORT',
  defaultValue: 8080,
);

const String kTestHost = 'http://localhost:$kTestServerPort';
const String kTestBaseUrl = '$kTestHost/api';

/// Returns true if backend is reachable (any HTTP response), false on connection error.
Future<bool> isBackendAvailable() async {
  try {
    await http
        .get(Uri.parse('$kTestHost/'))
        .timeout(const Duration(seconds: 3));
    return true;
  } catch (_) {
    return false;
  }
}

/// Like [loginAs] but skips the test suite (via [markTestSkipped]) if
/// the backend is unreachable or rate-limited (429/503).
Future<String> tryLoginAs(String email, String password) async {
  try {
    return await loginAs(email, password);
  } on ApiException catch (e) {
    final msg = e.message;
    if (msg.contains('429') || msg.contains('503') || msg.contains('connect')) {
      markTestSkipped(
        'Backend unavailable or rate-limited — skipping integration tests',
      );
    }
    rethrow;
  } catch (e) {
    markTestSkipped('Backend not reachable — skipping integration tests');
    rethrow;
  }
}

ApiClient makeClient({String? token}) {
  final client = ApiClient(client: http.Client(), baseUrl: kTestBaseUrl);
  if (token != null) client.setAuthToken(token);
  return client;
}

Future<String> loginAs(String email, String password) async {
  final client = makeClient();
  try {
    final data = await client.login(email, password);
    if (data == null) throw Exception('Login returned null for $email');
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('No token in login response: $data');
    }
    return token;
  } finally {
    client.dispose();
  }
}
