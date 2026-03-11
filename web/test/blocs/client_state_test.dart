import 'package:flutter_test/flutter_test.dart';
import 'package:oktopus/blocs/client/client_state.dart';
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
            id: 'c1', name: 'Alice', email: 'a@t.com', phone: '+491111'),
        TestFixtures.person(
            id: 'c2', name: 'Bob', email: 'b@t.com', phone: '+492222'),
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
  });
}
