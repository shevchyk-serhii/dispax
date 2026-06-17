import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/superadmin_analytics_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockApiClient extends Mock implements ApiClient {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

http.Response fakeResponse(int statusCode, [Object? body]) {
  final encoded = body == null ? '' : jsonEncode(body);
  return http.Response(encoded, statusCode);
}

void stubAnalytics(
  MockApiClient api, {
  required Map<String, dynamic> rides,
  required Map<String, dynamic> billing,
  required Map<String, dynamic> connections,
}) {
  when(
    () => api.get(any(that: startsWith('/superadmin/analytics/rides'))),
  ).thenAnswer((_) async => fakeResponse(200, rides));
  when(
    () => api.get(any(that: startsWith('/superadmin/analytics/billing'))),
  ).thenAnswer((_) async => fakeResponse(200, billing));
  when(
    () => api.get('/superadmin/analytics/connections'),
  ).thenAnswer((_) async => fakeResponse(200, connections));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockApiClient mockApiClient;

  setUp(() {
    mockApiClient = MockApiClient();
  });

  group('SuperAdminAnalyticsBloc', () {
    // Regression guard: the BLoC used to ignore the API bodies entirely and
    // always emit a zero-filled bundle. It must now parse the three responses.
    test(
      'parses ride/billing/connection stats from the API responses',
      () async {
        stubAnalytics(
          mockApiClient,
          rides: {
            'byStatus': {'Completed': 5},
            'totalRevenue': 1234.5,
            'ridesByCompany': {'acme': 5},
            'revenueByCompany': {'acme': 1234.5},
          },
          billing: {
            'revenueByCompany': {'acme': 1000.0},
            'overdueByCompany': {'acme': 2},
          },
          connections: {
            'activeSessions': 7,
            'activeSessionsByCompany': {'acme': 7},
          },
        );

        final bloc = SuperAdminAnalyticsBloc(mockApiClient);
        bloc.add(
          LoadAnalytics(
            from: DateTime.utc(2026, 1, 1),
            to: DateTime.utc(2026, 1, 31),
          ),
        );

        final states = await bloc.stream.take(2).toList();
        await bloc.close();

        expect(states[0], isA<AnalyticsLoading>());
        final loaded = states[1];
        expect(loaded, isA<AnalyticsLoaded>());
        final data = (loaded as AnalyticsLoaded).data;
        expect(data.rides.totalRevenue, 1234.5);
        expect(data.rides.byStatus['Completed'], 5);
        expect(data.billing.overdueByCompany['acme'], 2);
        expect(data.connections.activeSessions, 7);
      },
    );

    blocTest<SuperAdminAnalyticsBloc, SuperAdminAnalyticsState>(
      'emits [AnalyticsLoading, AnalyticsError] when a request fails',
      build: () {
        when(
          () => mockApiClient.get(
            any(that: startsWith('/superadmin/analytics/rides')),
          ),
        ).thenAnswer((_) async => fakeResponse(500));
        when(
          () => mockApiClient.get(
            any(that: startsWith('/superadmin/analytics/billing')),
          ),
        ).thenAnswer((_) async => fakeResponse(200, <String, dynamic>{}));
        when(
          () => mockApiClient.get('/superadmin/analytics/connections'),
        ).thenAnswer((_) async => fakeResponse(200, <String, dynamic>{}));
        return SuperAdminAnalyticsBloc(mockApiClient);
      },
      act: (bloc) => bloc.add(
        LoadAnalytics(
          from: DateTime.utc(2026, 1, 1),
          to: DateTime.utc(2026, 1, 31),
        ),
      ),
      expect: () => [isA<AnalyticsLoading>(), isA<AnalyticsError>()],
    );
  });
}
