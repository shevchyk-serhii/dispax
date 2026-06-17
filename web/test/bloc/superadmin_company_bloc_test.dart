import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/superadmin_companies_screen.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockApiClient extends Mock implements ApiClient {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a minimal http.Response that ApiClient methods return.
/// The body is JSON-encoded, mirroring what the real server sends.
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

  group('SuperAdminCompanyBloc', () {
    group('LoadCompanies', () {
      // Regression guard: the BLoC must `jsonDecode(response.body)` before
      // parsing, since `http.Response.body` is always a String. A previous
      // version checked `(response.body as dynamic) is List`, which always
      // evaluated to false and produced an empty list.
      test('parses the companies list from the JSON body', () async {
        when(() => mockApiClient.get('/superadmin/companies')).thenAnswer(
          (_) async => fakeResponse(200, [
            {
              'id': 'c1',
              'name': 'Acme Transfers',
              'email': 'ops@acme.example',
              'phone': '+49 89 000000',
              'address': 'München',
              'status': 'Active',
              'subscriptionPlan': 'Pro',
            },
          ]),
        );

        final bloc = SuperAdminCompanyBloc(mockApiClient);
        bloc.add(LoadCompanies());

        final states = await bloc.stream.take(2).toList();
        await bloc.close();

        expect(states[0], isA<CompaniesLoading>());
        final loaded = states[1];
        expect(loaded, isA<CompaniesLoaded>());
        final companies = (loaded as CompaniesLoaded).companies;
        expect(companies, hasLength(1));
        expect(companies.first.id, 'c1');
        expect(companies.first.name, 'Acme Transfers');
      });

      blocTest<SuperAdminCompanyBloc, SuperAdminCompanyState>(
        'emits [CompaniesLoading, CompaniesError] on non-200 status',
        build: () {
          when(
            () => mockApiClient.get('/superadmin/companies'),
          ).thenAnswer((_) async => fakeResponse(500));
          return SuperAdminCompanyBloc(mockApiClient);
        },
        act: (bloc) => bloc.add(LoadCompanies()),
        expect: () => [isA<CompaniesLoading>(), isA<CompaniesError>()],
      );
    });
  });
}
