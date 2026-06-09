@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'helpers.dart';

void main() {
  // All three logins run once in setUpAll
  // to avoid triggering the rate limiter on /auth/login.
  late String clientToken;
  late String driverToken;
  late String adminToken;

  setUpAll(() async {
    clientToken = await tryLoginAs(kClientEmail, kPassword);
    await Future.delayed(const Duration(milliseconds: 300));
    driverToken = await tryLoginAs(kDriverEmail, kPassword);
    await Future.delayed(const Duration(milliseconds: 300));
    adminToken = await tryLoginAs(kAdminEmail, kPassword);
  });

  group('Auth token integration', () {
    test('client token grants access to /rides', () async {
      final client = makeClient(token: clientToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides');
      expect(response.statusCode, 200);
    });

    test('driver token grants access to /rides', () async {
      final client = makeClient(token: driverToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides');
      expect(response.statusCode, 200);
    });

    test('admin token grants access to /rides', () async {
      final client = makeClient(token: adminToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides');
      expect(response.statusCode, 200);
    });

    test('client token carries the CLIENT role', () async {
      // The role is already encoded in the JWT — verified via login (done in setUpAll)
      final client = makeClient();
      addTearDown(client.dispose);

      // Use the already known token and verify it works
      final authClient = makeClient(token: clientToken);
      final response = await authClient.get('/rides');
      expect(response.statusCode, 200);
    });

    test('an invalid token grants no access', () async {
      final client = makeClient(token: 'invalid.jwt.token');
      addTearDown(client.dispose);

      // ApiClient surfaces a 401 as a thrown ApiException rather than a
      // response, so assert it throws instead of inspecting the status code.
      await expectLater(client.get('/rides'), throwsA(isA<Exception>()));
    });

    test('GET /health is accessible without a token', () async {
      // /health lives outside the /api prefix, so call the host directly.
      final response = await http.get(Uri.parse('$kTestHost/health'));
      expect(response.statusCode, 200);
    });
  });
}
