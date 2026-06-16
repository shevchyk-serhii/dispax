import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dispax/blocs/client/client_bloc.dart';
import 'package:dispax/blocs/client/client_event.dart';
import 'package:dispax/blocs/client/client_state.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/models/user_requests.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

class FakeCreateUserRequest extends Fake implements CreateUserRequest {}

class FakeUpdateUserRequest extends Fake implements UpdateUserRequest {}

void main() {
  late MockUserService mockUserService;
  late Person testClient;
  late List<Person> testClients;

  setUpAll(() {
    registerFallbackValue(FakeCreateUserRequest());
    registerFallbackValue(FakeUpdateUserRequest());
  });

  setUp(() {
    mockUserService = MockUserService();
    testClient = TestFixtures.person(id: 'client-1', name: 'Client A');
    testClients = [
      testClient,
      TestFixtures.person(
        id: 'client-2',
        name: 'Client B',
        email: 'b@test.com',
      ),
    ];

    when(() => mockUserService.dispose()).thenReturn(null);
  });

  ClientBloc buildBloc() => ClientBloc(userService: mockUserService);

  group('ClientBloc', () {
    test('initial state is ClientState.initial()', () {
      final bloc = buildBloc();
      expect(bloc.state, ClientState.initial());
      bloc.close();
    });

    blocTest<ClientBloc, ClientState>(
      'ClientLoadRequested emits loading then loaded',
      build: () {
        when(
          () => mockUserService.getClients(),
        ).thenAnswer((_) async => testClients);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ClientLoadRequested()),
      expect: () => [ClientState.loading(), ClientState.loaded(testClients)],
    );

    blocTest<ClientBloc, ClientState>(
      'ClientLoadRequested emits error on failure',
      build: () {
        when(
          () => mockUserService.getClients(),
        ).thenThrow(ApiException('fail'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const ClientLoadRequested()),
      expect: () => [
        ClientState.loading(),
        isA<ClientState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<ClientBloc, ClientState>(
      'ClientCreateRequested emits loading then loaded with new client',
      build: () {
        final newClient = TestFixtures.person(
          id: 'client-new',
          name: 'New Client',
        );
        when(
          () => mockUserService.createClient(any()),
        ).thenAnswer((_) async => newClient);
        return buildBloc();
      },
      seed: () => ClientState.loaded([testClient]),
      act: (bloc) => bloc.add(
        const ClientCreateRequested(
          request: CreateUserRequest(name: 'New', email: 'new@test.com'),
        ),
      ),
      expect: () => [
        isA<ClientState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ClientState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having((s) => s.clients.length, 'clients.length', 2),
      ],
    );

    blocTest<ClientBloc, ClientState>(
      'ClientCreateRequested emits error on failure',
      build: () {
        when(
          () => mockUserService.createClient(any()),
        ).thenThrow(ApiException('fail'));
        return buildBloc();
      },
      seed: () => ClientState.loaded([testClient]),
      act: (bloc) => bloc.add(
        const ClientCreateRequested(
          request: CreateUserRequest(name: 'X', email: 'x@test.com'),
        ),
      ),
      expect: () => [
        isA<ClientState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ClientState>().having((s) => s.hasError, 'hasError', true),
      ],
    );

    blocTest<ClientBloc, ClientState>(
      'ClientUpdateRequested emits loading then loaded with updated client',
      build: () {
        final updated = TestFixtures.person(
          id: 'client-1',
          name: 'Updated Name',
        );
        when(
          () => mockUserService.updateClient(any(), any()),
        ).thenAnswer((_) async => updated);
        return buildBloc();
      },
      seed: () => ClientState.loaded([testClient]),
      act: (bloc) => bloc.add(
        const ClientUpdateRequested(
          clientId: 'client-1',
          request: UpdateUserRequest(name: 'Updated Name'),
        ),
      ),
      expect: () => [
        isA<ClientState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ClientState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having((s) => s.clients.first.name, 'name', 'Updated Name'),
      ],
    );

    blocTest<ClientBloc, ClientState>(
      'ClientDeactivateRequested emits loading then loaded with client removed',
      build: () {
        when(
          () => mockUserService.deactivateClient('client-1'),
        ).thenAnswer((_) async {});
        return buildBloc();
      },
      seed: () => ClientState.loaded(testClients),
      act: (bloc) =>
          bloc.add(const ClientDeactivateRequested(clientId: 'client-1')),
      expect: () => [
        isA<ClientState>().having((s) => s.isLoading, 'isLoading', true),
        isA<ClientState>()
            .having((s) => s.isLoaded, 'isLoaded', true)
            .having((s) => s.clients.length, 'clients.length', 1)
            .having((s) => s.clients.first.id, 'id', 'client-2'),
      ],
    );

    blocTest<ClientBloc, ClientState>(
      'ClientSearchRequested updates searchQuery',
      build: buildBloc,
      seed: () => ClientState.loaded(testClients),
      act: (bloc) => bloc.add(const ClientSearchRequested(query: 'Client A')),
      expect: () => [
        isA<ClientState>().having(
          (s) => s.searchQuery,
          'searchQuery',
          'Client A',
        ),
      ],
    );
  });
}
