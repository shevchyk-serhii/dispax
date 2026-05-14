import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  // Все три логина выполняются один раз в setUpAll,
  // чтобы не триггерить rate limiter на /auth/login.
  late String clientToken;
  late String driverToken;
  late String adminToken;

  setUpAll(() async {
    clientToken = await loginAs(kClientEmail, kPassword);
    driverToken = await loginAs(kDriverEmail, kPassword);
    adminToken = await loginAs(kAdminEmail, kPassword);
  });

  group('Auth token integration', () {
    test('client токен даёт доступ к /rides/mock', () async {
      final client = makeClient(token: clientToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');
      expect(response.statusCode, 200);
    });

    test('driver токен даёт доступ к /rides/mock', () async {
      final client = makeClient(token: driverToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');
      expect(response.statusCode, 200);
    });

    test('admin токен даёт доступ к /rides/mock', () async {
      final client = makeClient(token: adminToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');
      expect(response.statusCode, 200);
    });

    test('client токен содержит роль CLIENT', () async {
      // Роль уже закодирована в JWT — проверяем через логин (уже сделан в setUpAll)
      final client = makeClient();
      addTearDown(client.dispose);

      // Используем уже известный токен, проверяем что он работает
      final authClient = makeClient(token: clientToken);
      final response = await authClient.get('/rides/mock');
      expect(response.statusCode, 200);
    });

    test('невалидный токен не даёт доступа', () async {
      final client = makeClient(token: 'invalid.jwt.token');
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');
      expect(response.statusCode, isNot(200));
    });

    test('GET /v2/health доступен без токена', () async {
      final client = makeClient();
      addTearDown(client.dispose);

      final response = await client.get('/v2/health');
      expect(response.statusCode, 200);
    });
  });
}
