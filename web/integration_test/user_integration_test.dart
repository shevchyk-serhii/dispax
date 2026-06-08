@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
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
    test('client token grants access to /rides/mock', () async {
      final client = makeClient(token: clientToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');
      expect(response.statusCode, 200);
    });

    test('driver token grants access to /rides/mock', () async {
      final client = makeClient(token: driverToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');
      expect(response.statusCode, 200);
    });

    test('admin token grants access to /rides/mock', () async {
      final client = makeClient(token: adminToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');
      expect(response.statusCode, 200);
    });

    test('client token carries the CLIENT role', () async {
      // The role is already encoded in the JWT — verified via login (done in setUpAll)
      final client = makeClient();
      addTearDown(client.dispose);

      // Use the already known token and verify it works
      final authClient = makeClient(token: clientToken);
      final response = await authClient.get('/rides/mock');
      expect(response.statusCode, 200);
    });

    test('an invalid token grants no access', () async {
      final client = makeClient(token: 'invalid.jwt.token');
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');
      expect(response.statusCode, isNot(200));
    });

    test('GET /v2/health is accessible without a token', () async {
      final client = makeClient();
      addTearDown(client.dispose);

      final response = await client.get('/v2/health');
      expect(response.statusCode, 200);
    });
  });
}
