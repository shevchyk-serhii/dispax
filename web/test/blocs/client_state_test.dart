import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/blocs/client/client_state.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('ClientState', () {
    test('filteredClients returns all when query empty', () {
      final clients = [
        TestFixtures.person(id: 'c1', name: 'Alice', email: 'alice@test.com'),
        TestFixtures.person(id: 'c2', name: 'Bob', email: 'bob@test.com'),
      ];
      final state = ClientState(
        status: ClientStateStatus.loaded,
        clients: clients,
        searchQuery: '',
      );

      expect(state.filteredClients, clients);
    });

    test('filteredClients filters by name', () {
      final clients = [
        TestFixtures.person(id: 'c1', name: 'Alice', email: 'alice@test.com'),
        TestFixtures.person(id: 'c2', name: 'Bob', email: 'bob@test.com'),
      ];
      final state = ClientState(
        status: ClientStateStatus.loaded,
        clients: clients,
        searchQuery: 'alice',
      );

      expect(state.filteredClients.length, 1);
      expect(state.filteredClients.first.name, 'Alice');
    });

    test('filteredClients filters by email', () {
      final clients = [
        TestFixtures.person(id: 'c1', name: 'Alice', email: 'alice@test.com'),
        TestFixtures.person(id: 'c2', name: 'Bob', email: 'bob@test.com'),
      ];
      final state = ClientState(
        status: ClientStateStatus.loaded,
        clients: clients,
        searchQuery: 'bob@',
      );

      expect(state.filteredClients.length, 1);
      expect(state.filteredClients.first.name, 'Bob');
    });

    test('filteredClients filters by phone', () {
      final clients = [
        TestFixtures.person(
          id: 'c1',
          name: 'Alice',
          email: 'a@t.com',
          phone: '+491111',
        ),
        TestFixtures.person(
          id: 'c2',
          name: 'Bob',
          email: 'b@t.com',
          phone: '+492222',
        ),
      ];
      final state = ClientState(
        status: ClientStateStatus.loaded,
        clients: clients,
        searchQuery: '2222',
      );

      expect(state.filteredClients.length, 1);
      expect(state.filteredClients.first.name, 'Bob');
    });

    test('isLoading getter', () {
      expect(ClientState.loading().isLoading, isTrue);
      expect(ClientState.loaded([]).isLoading, isFalse);
    });

    test('isLoaded getter', () {
      expect(ClientState.loaded([]).isLoaded, isTrue);
      expect(ClientState.loading().isLoaded, isFalse);
    });

    test('hasError getter', () {
      expect(ClientState.error('e').hasError, isTrue);
      expect(ClientState.loaded([]).hasError, isFalse);
    });

    group('copyWith', () {
      // Regression: copyWith must KEEP the existing errorMessage/error when
      // the caller does not pass them. Before the fix, `errorMessage:
      // errorMessage` (no sentinel) silently nulled them, so an unrelated
      // copyWith (e.g. a search-query update) on an error state lost the
      // error text. Same pattern as RideState.
      test('preserves errorMessage and error when not overridden', () {
        final cause = ApiException('boom', statusCode: 500);
        final original = ClientState.error(
          'Failed to create client',
          cause: cause,
        );
        final copied = original.copyWith(searchQuery: 'anna');

        expect(copied.status, ClientStateStatus.error);
        expect(
          copied.errorMessage,
          'Failed to create client',
          reason: 'copyWith must not drop the existing errorMessage',
        );
        expect(
          copied.error,
          same(cause),
          reason: 'copyWith must not drop the typed cause',
        );
      });

      // The flip side: explicit null must still clear.
      test('clears errorMessage and error when null is passed explicitly', () {
        final original = ClientState.error(
          'stale',
          cause: ApiException('boom', statusCode: 503),
        );
        final copied = original.copyWith(
          status: ClientStateStatus.loading,
          errorMessage: null,
          error: null,
        );

        expect(copied.status, ClientStateStatus.loading);
        expect(copied.errorMessage, isNull);
        expect(copied.error, isNull);
      });

      test('overrides errorMessage when a new value is passed', () {
        expect(
          ClientState.error('old').copyWith(errorMessage: 'new').errorMessage,
          'new',
        );
      });
    });
  });
}
