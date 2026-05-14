import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';

void main() {
  group('Auth integration', () {
    test('login с валидными данными возвращает токен', () async {
      final client = makeClient();
      addTearDown(client.dispose);

      final data = await client.login(kClientEmail, kClientPassword);

      expect(data, isNotNull);
      expect(data!['token'], isA<String>());
      expect((data['token'] as String).isNotEmpty, isTrue);
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

    test('ответ содержит person.email и person.role', () async {
      final client = makeClient();
      addTearDown(client.dispose);

      final data = await client.login(kClientEmail, kClientPassword);

      expect(data, isNotNull);
      final person = data!['person'] as Map<String, dynamic>;
      expect(person['email'], kClientEmail);
      expect(person['role'], isA<String>());
    });

    test('driver може залогиниться', () async {
      final client = makeClient();
      addTearDown(client.dispose);

      final data = await client.login(kDriverEmail, kPassword);

      expect(data, isNotNull);
      expect(data!['token'], isA<String>());
    });
  });
}
