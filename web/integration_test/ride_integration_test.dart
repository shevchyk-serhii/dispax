@Tags(['integration'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'helpers.dart';
// ignore_for_file: unused_import

void main() {
  late String clientToken;

  setUpAll(() async {
    clientToken = await tryLoginAs(kClientEmail, kPassword);
  });

  group('Ride endpoints integration', () {
    test('GET /rides/mock with a token returns a list of rides', () async {
      final client = makeClient(token: clientToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body);
      expect(body, isA<List>());
    });

    test('GET /rides/mock without a token returns an error', () async {
      final client = makeClient();
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');

      expect(response.statusCode, isNot(200));
    });

    test('GET /v2/health returns status OK', () async {
      final client = makeClient();
      addTearDown(client.dispose);

      final response = await client.get('/v2/health');

      expect(response.statusCode, 200);
    });

    test('rides contain the required fields', () async {
      final client = makeClient(token: clientToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides/mock');
      final rides = jsonDecode(response.body) as List;

      expect(rides, isNotEmpty);
      final ride = rides.first as Map<String, dynamic>;
      expect(ride.containsKey('id'), isTrue);
      expect(ride.containsKey('status'), isTrue);
    });
  });
}
