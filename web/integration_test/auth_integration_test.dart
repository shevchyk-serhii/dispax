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
    test('login with valid credentials returns a token', () {
      expect(loginResponse, isNotNull);
      expect(loginResponse!['token'], isA<String>());
      expect((loginResponse!['token'] as String).isNotEmpty, isTrue);
    });

    test('login with a wrong password returns null', () async {
      final client = makeClient();
      addTearDown(client.dispose);
      final data = await client.login(kClientEmail, 'wrongpassword');
      expect(data, isNull);
    });

    test('login with a non-existent email returns null', () async {
      final client = makeClient();
      addTearDown(client.dispose);
      final data = await client.login('nobody@example.com', kPassword);
      expect(data, isNull);
    });

    test('response contains person.email and person.role', () {
      expect(loginResponse, isNotNull);
      final person = loginResponse!['person'] as Map<String, dynamic>;
      expect(person['email'], kClientEmail);
      expect(person['role'], isA<String>());
    });

    test('driver can log in', () {
      expect(driverLoginResponse, isNotNull);
      expect(driverLoginResponse!['token'], isA<String>());
    });
  });
}
