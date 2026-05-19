@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  Map<String, dynamic>? loginResponse;
  Map<String, dynamic>? driverLoginResponse;

  setUpAll(() async {
    final client = makeClient();
    try {
      loginResponse = await client.login(kClientEmail, kClientPassword)
          .catchError((e) {
            final msg = e.toString();
            if (msg.contains('429') || msg.contains('503') || msg.contains('connect')) {
              markTestSkipped('Backend unavailable or rate-limited — skipping');
              throw e;
            }
            throw e;
          });
      await Future.delayed(const Duration(milliseconds: 300));
      driverLoginResponse = await client.login(kDriverEmail, kPassword)
          .catchError((e) { throw e; });
    } finally {
      client.dispose();
    }
  });

  group('Auth integration', () {
    test('login с валидными данными возвращает токен', () {
      expect(loginResponse, isNotNull);
      expect(loginResponse!['token'], isA<String>());
      expect((loginResponse!['token'] as String).isNotEmpty, isTrue);
    });

    test('login с неверным паролем возвращает null', () async {
      final client = makeClient();
      addTearDown(client.dispose);
      final data = await client.login(kClientEmail, 'wrongpassword');
      expect(data, isNull);
    });

    test('login с несуществующим email возвращает null', () async {
      final client = makeClient();
      addTearDown(client.dispose);
      final data = await client.login('nobody@example.com', kPassword);
      expect(data, isNull);
    });

    test('ответ содержит person.email и person.role', () {
      expect(loginResponse, isNotNull);
      final person = loginResponse!['person'] as Map<String, dynamic>;
      expect(person['email'], kClientEmail);
      expect(person['role'], isA<String>());
    });

    test('driver може залогиниться', () {
      expect(driverLoginResponse, isNotNull);
      expect(driverLoginResponse!['token'], isA<String>());
    });
  });
}
