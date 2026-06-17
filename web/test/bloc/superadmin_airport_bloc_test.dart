import 'dart:convert';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/superadmin_airport_exits_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockApiClient extends Mock implements ApiClient {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a minimal http.Response that ApiClient methods return.
http.Response fakeResponse(int statusCode, [Object? body]) {
  final encoded = body == null ? '' : jsonEncode(body);
  return http.Response(encoded, statusCode);
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockApiClient mockApiClient;

  setUp(() {
    mockApiClient = MockApiClient();
  });

  group('SuperAdminAirportBloc', () {
    // -----------------------------------------------------------------------
    // LoadAirports
    // -----------------------------------------------------------------------

    group('LoadAirports', () {
      blocTest<SuperAdminAirportBloc, SuperAdminAirportState>(
        'emits [AirportsLoading, AirportsLoaded] on 200',
        build: () {
          // The API returns 200 with a JSON list of airports.
          when(() => mockApiClient.get('/superadmin/airports')).thenAnswer(
            (_) async => fakeResponse(200, [
              {
                'code': 'MUC',
                'name': 'München Franz Josef Strauß',
                'country': 'DE',
                'landingLat': 48.3537,
                'landingLon': 11.7860,
                'landingRadius': 2000,
                'isActive': true,
                'zones': <dynamic>[],
              },
            ]),
          );
          return SuperAdminAirportBloc(mockApiClient);
        },
        act: (bloc) => bloc.add(LoadAirports()),
        expect: () => [isA<AirportsLoading>(), isA<AirportsLoaded>()],
        verify: (_) {
          // Verify the API was called exactly once.
          verify(() => mockApiClient.get('/superadmin/airports')).called(1);
        },
      );

      // Regression guard: the BLoC must `jsonDecode(response.body)` before
      // parsing, since `http.Response.body` is always a String. A previous
      // version checked `(response.body as dynamic) is List`, which always
      // evaluated to false and produced an empty list.
      test(
        'AirportsLoaded parses the airports list from the JSON body',
        () async {
          when(() => mockApiClient.get('/superadmin/airports')).thenAnswer(
            (_) async => fakeResponse(200, [
              {
                'code': 'MUC',
                'name': 'MUC Airport',
                'country': 'DE',
                'landingLat': 48.0,
                'landingLon': 11.0,
                'landingRadius': 2000,
                'isActive': true,
                'zones': <dynamic>[],
              },
            ]),
          );

          final bloc = SuperAdminAirportBloc(mockApiClient);
          bloc.add(LoadAirports());

          final states = await bloc.stream.take(2).toList();
          await bloc.close();

          expect(states[0], isA<AirportsLoading>());
          final loaded = states[1];
          expect(loaded, isA<AirportsLoaded>());
          final airports = (loaded as AirportsLoaded).airports;
          expect(airports, hasLength(1));
          expect(airports.first.code, 'MUC');
        },
      );

      blocTest<SuperAdminAirportBloc, SuperAdminAirportState>(
        'emits [AirportsLoading, AirportsError] on 403',
        build: () {
          when(
            () => mockApiClient.get('/superadmin/airports'),
          ).thenAnswer((_) async => fakeResponse(403));
          return SuperAdminAirportBloc(mockApiClient);
        },
        act: (bloc) => bloc.add(LoadAirports()),
        expect: () => [isA<AirportsLoading>(), isA<AirportsError>()],
      );

      blocTest<SuperAdminAirportBloc, SuperAdminAirportState>(
        'emits [AirportsLoading, AirportsError] on non-200 status (500)',
        build: () {
          when(
            () => mockApiClient.get('/superadmin/airports'),
          ).thenAnswer((_) async => fakeResponse(500));
          return SuperAdminAirportBloc(mockApiClient);
        },
        act: (bloc) => bloc.add(LoadAirports()),
        expect: () => [isA<AirportsLoading>(), isA<AirportsError>()],
      );

      blocTest<SuperAdminAirportBloc, SuperAdminAirportState>(
        'emits [AirportsLoading, AirportsError] when API throws exception',
        build: () {
          when(
            () => mockApiClient.get('/superadmin/airports'),
          ).thenThrow(ApiException('network error'));
          return SuperAdminAirportBloc(mockApiClient);
        },
        act: (bloc) => bloc.add(LoadAirports()),
        expect: () => [isA<AirportsLoading>(), isA<AirportsError>()],
      );
    });

    // -----------------------------------------------------------------------
    // CreateAirport → calls POST, then reloads (emits Loading → Loaded)
    // -----------------------------------------------------------------------

    group('CreateAirport', () {
      blocTest<SuperAdminAirportBloc, SuperAdminAirportState>(
        'calls POST /superadmin/airports then triggers LoadAirports on 201',
        build: () {
          // POST responds 201
          when(
            () => mockApiClient.post('/superadmin/airports', any()),
          ).thenAnswer(
            (_) async => fakeResponse(201, {
              'code': 'BER',
              'name': 'Berlin Brandenburg',
              'country': 'DE',
              'landingLat': 52.3667,
              'landingLon': 13.5033,
              'landingRadius': 1500,
              'isActive': true,
              'zones': <dynamic>[],
              'createdAt': '2026-01-01T00:00:00Z',
              'updatedAt': '2026-01-01T00:00:00Z',
            }),
          );
          // Subsequent GET for reload
          when(
            () => mockApiClient.get('/superadmin/airports'),
          ).thenAnswer((_) async => fakeResponse(200, <dynamic>[]));
          return SuperAdminAirportBloc(mockApiClient);
        },
        act: (bloc) => bloc.add(
          CreateAirport(
            code: 'BER',
            name: 'Berlin Brandenburg',
            country: 'DE',
            landingLat: 52.3667,
            landingLon: 13.5033,
            landingRadius: 1500,
          ),
        ),
        // CreateAirport calls POST → on success adds LoadAirports
        // LoadAirports emits Loading then Loaded
        expect: () => [isA<AirportsLoading>(), isA<AirportsLoaded>()],
        verify: (_) {
          verify(
            () => mockApiClient.post('/superadmin/airports', any()),
          ).called(1);
          verify(() => mockApiClient.get('/superadmin/airports')).called(1);
        },
      );

      blocTest<SuperAdminAirportBloc, SuperAdminAirportState>(
        'emits AirportsError when POST returns non-201/200 status',
        build: () {
          when(
            () => mockApiClient.post('/superadmin/airports', any()),
          ).thenAnswer((_) async => fakeResponse(400));
          return SuperAdminAirportBloc(mockApiClient);
        },
        act: (bloc) => bloc.add(
          CreateAirport(
            code: 'BAD',
            name: 'Bad Airport',
            country: 'DE',
            landingLat: 91.0, // invalid but BLoC doesn't validate client-side
            landingLon: 11.0,
            landingRadius: 1000,
          ),
        ),
        expect: () => [isA<AirportsError>()],
      );
    });

    // -----------------------------------------------------------------------
    // DeleteAirport
    // -----------------------------------------------------------------------

    group('DeleteAirport', () {
      blocTest<SuperAdminAirportBloc, SuperAdminAirportState>(
        'calls DELETE then triggers reload on 200',
        build: () {
          when(
            () => mockApiClient.delete('/superadmin/airports/MUC'),
          ).thenAnswer(
            (_) async => fakeResponse(200, {
              'code': 'MUC',
              'name': 'MUC',
              'country': 'DE',
              'landingLat': 48.0,
              'landingLon': 11.0,
              'landingRadius': 2000,
              'isActive': false,
              'zones': <dynamic>[],
              'createdAt': '2026-01-01T00:00:00Z',
              'updatedAt': '2026-01-01T00:00:00Z',
            }),
          );
          when(
            () => mockApiClient.get('/superadmin/airports'),
          ).thenAnswer((_) async => fakeResponse(200, <dynamic>[]));
          return SuperAdminAirportBloc(mockApiClient);
        },
        act: (bloc) => bloc.add(DeleteAirport('MUC')),
        expect: () => [isA<AirportsLoading>(), isA<AirportsLoaded>()],
        verify: (_) {
          verify(
            () => mockApiClient.delete('/superadmin/airports/MUC'),
          ).called(1);
        },
      );

      blocTest<SuperAdminAirportBloc, SuperAdminAirportState>(
        'emits AirportsError when DELETE returns non-200',
        build: () {
          when(
            () => mockApiClient.delete('/superadmin/airports/MUC'),
          ).thenAnswer((_) async => fakeResponse(404));
          return SuperAdminAirportBloc(mockApiClient);
        },
        act: (bloc) => bloc.add(DeleteAirport('MUC')),
        expect: () => [isA<AirportsError>()],
      );
    });
  });
}
