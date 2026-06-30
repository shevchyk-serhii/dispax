import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dispax/blocs/saved_places/saved_places_bloc.dart';
import 'package:dispax/blocs/saved_places/saved_places_event.dart';
import 'package:dispax/blocs/saved_places/saved_places_state.dart';
import 'package:dispax/modules/ride_management/models/client_address.dart';
import 'package:dispax/modules/ride_management/services/client_address_service.dart';

class MockClientAddressService extends Mock implements ClientAddressService {}

ClientAddress _makeAddress({
  required String id,
  required String label,
  required String address,
}) => ClientAddress(
  id: id,
  clientId: 'client-1',
  label: label,
  address: address,
  useCount: 1,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  late MockClientAddressService mockService;

  setUp(() {
    mockService = MockClientAddressService();
    when(() => mockService.dispose()).thenReturn(null);
  });

  SavedPlacesBloc buildBloc() => SavedPlacesBloc(addressService: mockService);

  group('SavedPlacesBloc', () {
    test('initial state is SavedPlacesState.initial()', () {
      final bloc = buildBloc();
      expect(bloc.state, SavedPlacesState.initial());
      expect(bloc.state.status, SavedPlacesStatus.initial);
      bloc.close();
    });

    blocTest<SavedPlacesBloc, SavedPlacesState>(
      'SavedPlacesLoadRequested emits loading then loaded',
      build: () {
        final places = [
          _makeAddress(id: '1', label: 'Home', address: 'Leopoldstr. 21'),
          _makeAddress(id: '2', label: 'Office', address: 'Maximilianstr. 5'),
        ];
        when(
          () => mockService.getAddresses('client-1'),
        ).thenAnswer((_) async => places);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SavedPlacesLoadRequested('client-1')),
      expect: () => [
        SavedPlacesState.loading(),
        isA<SavedPlacesState>()
            .having((s) => s.status, 'status', SavedPlacesStatus.loaded)
            .having((s) => s.places.length, 'places.length', 2),
      ],
    );

    blocTest<SavedPlacesBloc, SavedPlacesState>(
      'SavedPlacesLoadRequested emits loading then error on failure',
      build: () {
        when(
          () => mockService.getAddresses('client-1'),
        ).thenThrow(Exception('Network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SavedPlacesLoadRequested('client-1')),
      expect: () => [
        SavedPlacesState.loading(),
        isA<SavedPlacesState>()
            .having((s) => s.status, 'status', SavedPlacesStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Failed to load saved places'),
            )
            // Phase 3: typed cause carried (no display site today, asserted at
            // the bloc level — see the error-ux plan's SavedPlaces note).
            .having((s) => s.error, 'error', isNotNull),
      ],
    );

    test('findByLabel returns matching address case-insensitively', () {
      final home = _makeAddress(id: '1', label: 'Home', address: 'Musterstr 1');
      final state = SavedPlacesState.loaded([home]);
      expect(state.findByLabel('home'), home);
      expect(state.findByLabel('HOME'), home);
      expect(state.findByLabel('Airport'), isNull);
    });

    blocTest<SavedPlacesBloc, SavedPlacesState>(
      'SavedPlacesSaveRequested saves then reloads and emits loaded',
      build: () {
        final saved = _makeAddress(
          id: '3',
          label: 'Airport',
          address: 'Munich Airport',
        );
        when(
          () => mockService.saveAddress(
            clientId: 'client-1',
            label: 'Airport',
            address: 'Munich Airport',
            latitude: 48.35,
            longitude: 11.78,
          ),
        ).thenAnswer((_) async => saved);
        when(
          () => mockService.getAddresses('client-1'),
        ).thenAnswer((_) async => [saved]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SavedPlacesSaveRequested(
          clientId: 'client-1',
          label: 'Airport',
          address: 'Munich Airport',
          latitude: 48.35,
          longitude: 11.78,
        ),
      ),
      expect: () => [
        isA<SavedPlacesState>()
            .having((s) => s.status, 'status', SavedPlacesStatus.loaded)
            .having((s) => s.places.single.label, 'label', 'Airport'),
      ],
      verify: (_) {
        verify(
          () => mockService.saveAddress(
            clientId: 'client-1',
            label: 'Airport',
            address: 'Munich Airport',
            latitude: 48.35,
            longitude: 11.78,
          ),
        ).called(1);
      },
    );

    blocTest<SavedPlacesBloc, SavedPlacesState>(
      'SavedPlacesSaveRequested emits error when save fails',
      build: () {
        when(
          () => mockService.saveAddress(
            clientId: 'client-1',
            label: 'Home',
            address: 'Leopoldstr. 21',
            latitude: null,
            longitude: null,
          ),
        ).thenThrow(Exception('Network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SavedPlacesSaveRequested(
          clientId: 'client-1',
          label: 'Home',
          address: 'Leopoldstr. 21',
        ),
      ),
      expect: () => [
        isA<SavedPlacesState>()
            .having((s) => s.status, 'status', SavedPlacesStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Failed to save place'),
            ),
      ],
    );

    blocTest<SavedPlacesBloc, SavedPlacesState>(
      'SavedPlacesUpdateRequested updates then reloads and emits loaded',
      build: () {
        final renamed = _makeAddress(
          id: '1',
          label: 'Weekend home',
          address: 'Leopoldstr. 21',
        );
        when(
          () => mockService.updateAddress(
            clientId: 'client-1',
            addressId: '1',
            label: 'Weekend home',
            aliases: null,
          ),
        ).thenAnswer((_) async => renamed);
        when(
          () => mockService.getAddresses('client-1'),
        ).thenAnswer((_) async => [renamed]);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SavedPlacesUpdateRequested(
          clientId: 'client-1',
          addressId: '1',
          label: 'Weekend home',
        ),
      ),
      expect: () => [
        isA<SavedPlacesState>()
            .having((s) => s.status, 'status', SavedPlacesStatus.loaded)
            .having((s) => s.places.single.label, 'label', 'Weekend home'),
      ],
      verify: (_) {
        verify(
          () => mockService.updateAddress(
            clientId: 'client-1',
            addressId: '1',
            label: 'Weekend home',
            aliases: null,
          ),
        ).called(1);
      },
    );

    blocTest<SavedPlacesBloc, SavedPlacesState>(
      'SavedPlacesUpdateRequested emits error when update fails',
      build: () {
        when(
          () => mockService.updateAddress(
            clientId: 'client-1',
            addressId: '1',
            label: 'Weekend home',
            aliases: null,
          ),
        ).thenThrow(Exception('Network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SavedPlacesUpdateRequested(
          clientId: 'client-1',
          addressId: '1',
          label: 'Weekend home',
        ),
      ),
      expect: () => [
        isA<SavedPlacesState>()
            .having((s) => s.status, 'status', SavedPlacesStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Failed to update place'),
            ),
      ],
    );

    blocTest<SavedPlacesBloc, SavedPlacesState>(
      'SavedPlacesDeleteRequested deletes then reloads and emits loaded',
      build: () {
        when(
          () => mockService.deleteAddress('client-1', '1'),
        ).thenAnswer((_) async => true);
        when(
          () => mockService.getAddresses('client-1'),
        ).thenAnswer((_) async => []);
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SavedPlacesDeleteRequested(clientId: 'client-1', addressId: '1'),
      ),
      expect: () => [
        isA<SavedPlacesState>()
            .having((s) => s.status, 'status', SavedPlacesStatus.loaded)
            .having((s) => s.places, 'places', isEmpty),
      ],
      verify: (_) {
        verify(() => mockService.deleteAddress('client-1', '1')).called(1);
      },
    );

    blocTest<SavedPlacesBloc, SavedPlacesState>(
      'SavedPlacesDeleteRequested emits error when delete fails',
      build: () {
        when(
          () => mockService.deleteAddress('client-1', '1'),
        ).thenThrow(Exception('Network error'));
        return buildBloc();
      },
      act: (bloc) => bloc.add(
        const SavedPlacesDeleteRequested(clientId: 'client-1', addressId: '1'),
      ),
      expect: () => [
        isA<SavedPlacesState>()
            .having((s) => s.status, 'status', SavedPlacesStatus.error)
            .having(
              (s) => s.errorMessage,
              'errorMessage',
              contains('Failed to delete place'),
            ),
      ],
    );

    blocTest<SavedPlacesBloc, SavedPlacesState>(
      'empty addresses list emits loaded with empty list',
      build: () {
        when(
          () => mockService.getAddresses('client-1'),
        ).thenAnswer((_) async => []);
        return buildBloc();
      },
      act: (bloc) => bloc.add(const SavedPlacesLoadRequested('client-1')),
      expect: () => [
        SavedPlacesState.loading(),
        isA<SavedPlacesState>()
            .having((s) => s.status, 'status', SavedPlacesStatus.loaded)
            .having((s) => s.places, 'places', isEmpty),
      ],
    );
  });
}
