import 'package:flutter_bloc/flutter_bloc.dart';
import '../../modules/ride_management/services/client_address_service.dart';
import 'saved_places_event.dart';
import 'saved_places_state.dart';

class SavedPlacesBloc extends Bloc<SavedPlacesEvent, SavedPlacesState> {
  final ClientAddressService _addressService;

  SavedPlacesBloc({required ClientAddressService addressService})
    : _addressService = addressService,
      super(SavedPlacesState.initial()) {
    on<SavedPlacesLoadRequested>(_onLoadRequested);
    on<SavedPlacesSaveRequested>(_onSaveRequested);
    on<SavedPlacesUpdateRequested>(_onUpdateRequested);
    on<SavedPlacesDeleteRequested>(_onDeleteRequested);
  }

  Future<void> _onLoadRequested(
    SavedPlacesLoadRequested event,
    Emitter<SavedPlacesState> emit,
  ) async {
    emit(SavedPlacesState.loading());
    try {
      final places = await _addressService.getAddresses(event.clientId);
      emit(SavedPlacesState.loaded(places));
    } catch (e) {
      emit(SavedPlacesState.error('Failed to load saved places: $e'));
    }
  }

  Future<void> _onSaveRequested(
    SavedPlacesSaveRequested event,
    Emitter<SavedPlacesState> emit,
  ) async {
    try {
      await _addressService.saveAddress(
        clientId: event.clientId,
        label: event.label,
        address: event.address,
        latitude: event.latitude,
        longitude: event.longitude,
      );
      // Reload so findByLabel() picks up the newly saved place.
      final places = await _addressService.getAddresses(event.clientId);
      emit(SavedPlacesState.loaded(places));
    } catch (e) {
      emit(SavedPlacesState.error('Failed to save place: $e'));
    }
  }

  Future<void> _onUpdateRequested(
    SavedPlacesUpdateRequested event,
    Emitter<SavedPlacesState> emit,
  ) async {
    try {
      await _addressService.updateAddress(
        clientId: event.clientId,
        addressId: event.addressId,
        label: event.label,
        aliases: event.aliases,
      );
      // Reload so the renamed place is reflected.
      final places = await _addressService.getAddresses(event.clientId);
      emit(SavedPlacesState.loaded(places));
    } catch (e) {
      emit(SavedPlacesState.error('Failed to update place: $e'));
    }
  }

  Future<void> _onDeleteRequested(
    SavedPlacesDeleteRequested event,
    Emitter<SavedPlacesState> emit,
  ) async {
    try {
      await _addressService.deleteAddress(event.clientId, event.addressId);
      // Reload so the removed place disappears from the UI.
      final places = await _addressService.getAddresses(event.clientId);
      emit(SavedPlacesState.loaded(places));
    } catch (e) {
      emit(SavedPlacesState.error('Failed to delete place: $e'));
    }
  }

  @override
  Future<void> close() {
    _addressService.dispose();
    return super.close();
  }
}
