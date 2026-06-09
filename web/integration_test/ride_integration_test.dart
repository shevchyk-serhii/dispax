@Tags(['integration'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'helpers.dart';
// ignore_for_file: unused_import

void main() {
  late String clientToken;

  setUpAll(() async {
    clientToken = await tryLoginAs(kClientEmail, kPassword);
  });

  group('Ride endpoints integration', () {
    test('GET /rides with a token returns a list of rides', () async {
      final client = makeClient(token: clientToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides');

      expect(response.statusCode, 200);
      final body = jsonDecode(response.body);
      expect(body, isA<List>());
    });

    test('GET /rides without a token is rejected', () async {
      final client = makeClient();
      addTearDown(client.dispose);

      // ApiClient surfaces a 401 as a thrown ApiException rather than a
      // response, so assert it throws instead of inspecting the status code.
      await expectLater(client.get('/rides'), throwsA(isA<Exception>()));
    });

    test('GET /health returns status OK', () async {
      // /health lives outside the /api prefix, so call the host directly.
      final response = await http.get(Uri.parse('$kTestHost/health'));

      expect(response.statusCode, 200);
    });

    test('rides contain the required fields', () async {
      final client = makeClient(token: clientToken);
      addTearDown(client.dispose);

      final response = await client.get('/rides');
      final rides = jsonDecode(response.body) as List;

      expect(rides, isNotEmpty);
      final ride = rides.first as Map<String, dynamic>;
      expect(ride.containsKey('id'), isTrue);
      expect(ride.containsKey('status'), isTrue);
    });
  });
}
