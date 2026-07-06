import 'package:flutter_bloc/flutter_bloc.dart';
import '../../modules/ride_management/helpers/airport_catalog.dart';
import '../../modules/ride_management/helpers/tag_helpers.dart';
import '../../modules/ride_management/models/vehicle_class.dart';
import 'create_ride_form_event.dart';
import 'create_ride_form_state.dart';

class CreateRideFormBloc
    extends Bloc<CreateRideFormEvent, CreateRideFormState> {
  CreateRideFormBloc() : super(CreateRideFormState.initial()) {
    on<ClientNameChanged>(_onClientNameChanged);
    on<ClientSelected>(_onClientSelected);
    on<ClientPreselected>(_onClientPreselected);
    on<ClientCleared>(_onClientCleared);
    on<DriverSelected>(_onDriverSelected);
    on<DriverPreselected>(_onDriverPreselected);
    on<FromAddressChanged>(_onFromAddressChanged);
    on<ToAddressChanged>(_onToAddressChanged);
    on<FlightNumberChanged>(_onFlightNumberChanged);
    on<PickupDateTimeChanged>(_onPickupDateTimeChanged);
    on<ManualPickupTimeChanged>(_onManualPickupTimeChanged);
    on<FlightDepartureTimeChanged>(_onFlightDepartureTimeChanged);
    on<AirportTransferToggled>(_onAirportTransferToggled);
    on<ArrivalToggled>(_onArrivalToggled);
    on<GateSelected>(_onGateSelected);
    on<TerminalSelected>(_onTerminalSelected);
    on<NotesToggled>(_onNotesToggled);
    on<NotesChanged>(_onNotesChanged);
    on<RidePriceChanged>(_onRidePriceChanged);
    on<SpecialRequirementToggled>(_onSpecialRequirementToggled);
    on<TagAdded>(_onTagAdded);
    on<TagRemoved>(_onTagRemoved);
    on<FormCleared>(_onFormCleared);
    on<FormSubmitted>(_onFormSubmitted);
    on<SubmissionFailed>(_onSubmissionFailed);
    on<AddressesSwapped>(_onAddressesSwapped);
    on<NewClientModeToggled>(_onNewClientModeToggled);
    on<ProvisionalClientModeToggled>(_onProvisionalClientModeToggled);
    on<NewClientPhoneChanged>(_onNewClientPhoneChanged);
    on<VehicleClassSelected>(_onVehicleClassSelected);
    on<PaymentMethodSelected>(_onPaymentMethodSelected);
    on<ScheduleModeToggled>(_onScheduleModeToggled);
    on<EstimateReceived>(_onEstimateReceived);
    on<FormPrefilledFromRide>(_onFormPrefilledFromRide);
  }

  void _onFormPrefilledFromRide(
    FormPrefilledFromRide event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(CreateRideFormState.fromRide(event.ride));
  }

  void _onNotesToggled(NotesToggled event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(showNotes: !state.showNotes));
  }

  void _onNotesChanged(NotesChanged event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(notes: event.notes));
  }

  void _onRidePriceChanged(
    RidePriceChanged event,
    Emitter<CreateRideFormState> emit,
  ) {
    // A null price (empty/invalid input) clears it via the sentinel so the ride
    // is created without a price.
    if (event.price == null) {
      emit(state.copyWith(clearPrice: true));
    } else {
      emit(state.copyWith(price: event.price));
    }
  }

  void _onSpecialRequirementToggled(
    SpecialRequirementToggled event,
    Emitter<CreateRideFormState> emit,
  ) {
    final current = List<String>.from(state.specialRequirements);
    if (current.contains(event.requirement)) {
      current.remove(event.requirement);
    } else {
      current.add(event.requirement);
    }
    emit(state.copyWith(specialRequirements: current));
  }

  void _onTagAdded(TagAdded event, Emitter<CreateRideFormState> emit) {
    final cleaned = normalizeTag(event.tag);
    if (cleaned.isEmpty) return;
    // Case-insensitive de-dup so the UI matches the backend's normalization.
    final exists = state.tags.any(
      (t) => t.toLowerCase() == cleaned.toLowerCase(),
    );
    if (exists) return;
    emit(state.copyWith(tags: [...state.tags, cleaned]));
  }

  void _onTagRemoved(TagRemoved event, Emitter<CreateRideFormState> emit) {
    emit(
      state.copyWith(tags: state.tags.where((t) => t != event.tag).toList()),
    );
  }

  void _onClientNameChanged(
    ClientNameChanged event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(state.copyWith(clientName: event.clientName));
  }

  void _onClientSelected(
    ClientSelected event,
    Emitter<CreateRideFormState> emit,
  ) {
    final newFromAddress =
        event.defaultAddress != null && state.fromAddress.isEmpty
        ? event.defaultAddress!
        : null;
    final newState = state.copyWith(
      selectedClientId: event.clientId,
      clientName: event.clientName,
      fromAddress: newFromAddress ?? state.fromAddress,
    );
    emit(_checkAirportTransfer(newState));
  }

  void _onClientPreselected(
    ClientPreselected event,
    Emitter<CreateRideFormState> emit,
  ) {
    // Sets the client AND the baseline so that booking for oneself is not
    // treated as a user modification.
    emit(
      state.copyWith(
        selectedClientId: event.clientId,
        clientName: event.clientName,
        baselineClientId: event.clientId,
        baselineClientName: event.clientName,
      ),
    );
  }

  void _onClientCleared(
    ClientCleared event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(
      state.copyWith(clearClientId: true, clientName: '', newClientPhone: ''),
    );
  }

  void _onDriverSelected(
    DriverSelected event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(
      state.copyWith(
        selectedDriverId: event.driverId,
        clearDriverId: event.driverId == null,
      ),
    );
  }

  void _onDriverPreselected(
    DriverPreselected event,
    Emitter<CreateRideFormState> emit,
  ) {
    // Sets the driver AND the baseline so that preselecting self is not treated
    // as a user modification.
    emit(
      state.copyWith(
        selectedDriverId: event.driverId,
        baselineDriverId: event.driverId,
      ),
    );
  }

  void _onFromAddressChanged(
    FromAddressChanged event,
    Emitter<CreateRideFormState> emit,
  ) {
    final newState = _clearStaleEstimates(
      _clearSubmitting(state.copyWith(fromAddress: event.fromAddress)),
    );
    emit(_checkAirportTransfer(newState));
  }

  void _onToAddressChanged(
    ToAddressChanged event,
    Emitter<CreateRideFormState> emit,
  ) {
    final newState = _clearStaleEstimates(
      _clearSubmitting(state.copyWith(toAddress: event.toAddress)),
    );
    emit(_checkAirportTransfer(newState));
  }

  /// Drops any previously fetched price estimates when the route is incomplete
  /// (either endpoint empty). The estimate UI reads [estimateBusiness] /
  /// [estimateVan] directly, so leaving them set after an address is cleared
  /// would show a stale price for a route that no longer exists. When both
  /// endpoints are present the estimates are kept — the screen re-fetches for
  /// the new route and replaces them.
  CreateRideFormState _clearStaleEstimates(CreateRideFormState s) {
    final complete = s.fromAddress.isNotEmpty && s.toAddress.isNotEmpty;
    if (complete) return s;
    return s.copyWith(
      clearEstimateBusiness: true,
      clearEstimateVan: true,
      estimateUnavailable: false,
    );
  }

  void _onFlightNumberChanged(
    FlightNumberChanged event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(state.copyWith(flightNumber: event.flightNumber));
  }

  void _onPickupDateTimeChanged(
    PickupDateTimeChanged event,
    Emitter<CreateRideFormState> emit,
  ) {
    // Legacy handler: forward to manualPickupDateTime.
    emit(state.copyWith(manualPickupDateTime: event.pickupDateTime));
  }

  void _onManualPickupTimeChanged(
    ManualPickupTimeChanged event,
    Emitter<CreateRideFormState> emit,
  ) {
    if (event.pickupDateTime == null) {
      emit(state.copyWith(clearManualPickupDateTime: true));
    } else {
      emit(state.copyWith(manualPickupDateTime: event.pickupDateTime));
    }
  }

  void _onFlightDepartureTimeChanged(
    FlightDepartureTimeChanged event,
    Emitter<CreateRideFormState> emit,
  ) {
    if (event.flightDepartureTime == null) {
      emit(state.copyWith(clearFlightDepartureTime: true));
    } else {
      emit(state.copyWith(flightDepartureTime: event.flightDepartureTime));
    }
  }

  void _onAirportTransferToggled(
    AirportTransferToggled event,
    Emitter<CreateRideFormState> emit,
  ) {
    if (!event.isAirportTransfer) {
      // Clear the auto-filled airport address too, but keep an address the
      // operator typed by hand (only the canonical catalog address is removed).
      emit(
        _clearAirportAddresses(state).copyWith(
          isAirportTransfer: false,
          flightNumber: '',
          selectedGate: null,
          selectedTerminal: null,
          isArrival: false,
        ),
      );
    } else if (!state.isAirportTransfer) {
      // Transition off → on: a new airport transfer defaults to an arrival (the
      // client is picked up AT the airport), so the airport address goes into
      // the "From" field. When the flag was already on (e.g. auto-enabled by an
      // airport address the operator typed), keep the existing direction and
      // addresses — re-toggling must not flip arrival/departure.
      const arrival = true;
      emit(
        _applyAirportField(
          state.copyWith(isAirportTransfer: true, isArrival: arrival),
          isArrival: arrival,
        ),
      );
    }
  }

  void _onArrivalToggled(
    ArrivalToggled event,
    Emitter<CreateRideFormState> emit,
  ) {
    if (!state.isAirportTransfer || event.isArrival == state.isArrival) {
      emit(state.copyWith(isArrival: event.isArrival));
      return;
    }
    // The transfer is active and the direction actually flipped: swap From/To so
    // the airport moves to the field the new direction implies (arrival → From,
    // departure → To) while the operator-entered address moves to the other
    // field instead of being lost.
    emit(
      state.copyWith(
        isArrival: event.isArrival,
        fromAddress: state.toAddress,
        toAddress: state.fromAddress,
      ),
    );
  }

  /// Places the default airport address into the field implied by [isArrival]
  /// (arrival → From, departure → To) and clears any previously auto-filled
  /// airport address from the opposite field. Used only when the transfer is
  /// first enabled; an address the operator typed by hand in the opposite field
  /// is preserved.
  CreateRideFormState _applyAirportField(
    CreateRideFormState s, {
    required bool isArrival,
  }) {
    final airport = defaultAirport.address;
    if (isArrival) {
      return s.copyWith(
        fromAddress: airport,
        toAddress: isCatalogAirportAddress(s.toAddress) ? '' : s.toAddress,
      );
    }
    return s.copyWith(
      toAddress: airport,
      fromAddress: isCatalogAirportAddress(s.fromAddress) ? '' : s.fromAddress,
    );
  }

  /// Removes an auto-filled airport address from either endpoint, leaving an
  /// operator-typed address untouched.
  CreateRideFormState _clearAirportAddresses(CreateRideFormState s) {
    return s.copyWith(
      fromAddress: isCatalogAirportAddress(s.fromAddress) ? '' : s.fromAddress,
      toAddress: isCatalogAirportAddress(s.toAddress) ? '' : s.toAddress,
    );
  }

  void _onGateSelected(GateSelected event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(selectedGate: event.gate));
  }

  void _onTerminalSelected(
    TerminalSelected event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(state.copyWith(selectedTerminal: event.terminal));
  }

  void _onFormCleared(FormCleared event, Emitter<CreateRideFormState> emit) {
    emit(CreateRideFormState.initial());
  }

  void _onAddressesSwapped(
    AddressesSwapped event,
    Emitter<CreateRideFormState> emit,
  ) {
    final newState = state.copyWith(
      fromAddress: state.toAddress,
      toAddress: state.fromAddress,
    );
    emit(_checkAirportTransfer(newState));
  }

  void _onNewClientModeToggled(
    NewClientModeToggled event,
    Emitter<CreateRideFormState> emit,
  ) {
    if (state.isNewClient) {
      // Back to search — reset the new-client fields
      emit(
        state.copyWith(
          isNewClient: false,
          newClientPhone: '',
          clientName: '',
          clearClientId: true,
        ),
      );
    } else {
      // Switching to creating a new client — reset the selected one
      emit(
        state.copyWith(isNewClient: true, clearClientId: true, clientName: ''),
      );
    }
  }

  void _onProvisionalClientModeToggled(
    ProvisionalClientModeToggled event,
    Emitter<CreateRideFormState> emit,
  ) {
    if (state.isProvisionalClient) {
      // Turning off provisional mode — reset to normal state.
      emit(
        state.copyWith(
          isProvisionalClient: false,
          isNewClient: false,
          clientName: '',
          newClientPhone: '',
          clearClientId: true,
        ),
      );
    } else {
      // Turning on provisional mode — clear any selected/typed client info
      // so a stale selection cannot leak into the provisional submission.
      emit(
        state.copyWith(
          isProvisionalClient: true,
          isNewClient: false,
          clientName: '',
          newClientPhone: '',
          clearClientId: true,
        ),
      );
    }
  }

  void _onNewClientPhoneChanged(
    NewClientPhoneChanged event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(state.copyWith(newClientPhone: event.phone));
  }

  void _onFormSubmitted(
    FormSubmitted event,
    Emitter<CreateRideFormState> emit,
  ) {
    if (state.isValid) {
      emit(state.copyWith(status: CreateRideFormStatus.submitting));
    }
  }

  void _onSubmissionFailed(
    SubmissionFailed event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(_clearSubmitting(state));
  }

  /// Returns [s] back to the initial status if it is currently submitting.
  /// The "Create Ride" button is disabled while submitting; without this the
  /// form would stay stuck after a failed submit and the button would never
  /// re-enable, even once the user fixes the offending field.
  CreateRideFormState _clearSubmitting(CreateRideFormState s) =>
      s.status == CreateRideFormStatus.submitting
      ? s.copyWith(status: CreateRideFormStatus.initial)
      : s;

  void _onVehicleClassSelected(
    VehicleClassSelected event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(state.copyWith(selectedVehicleClass: event.vehicleClass));
  }

  void _onPaymentMethodSelected(
    PaymentMethodSelected event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(state.copyWith(selectedPaymentMethod: event.paymentMethod));
  }

  void _onScheduleModeToggled(
    ScheduleModeToggled event,
    Emitter<CreateRideFormState> emit,
  ) {
    if (!event.scheduled) {
      // ASAP → set manualPickupDateTime to now so the backend treats it as immediate.
      emit(
        state.copyWith(
          isScheduled: false,
          manualPickupDateTime: DateTime.now(),
        ),
      );
    } else {
      emit(
        state.copyWith(
          isScheduled: true,
          manualPickupDateTime: DateTime.now().add(const Duration(hours: 1)),
        ),
      );
    }
  }

  void _onEstimateReceived(
    EstimateReceived event,
    Emitter<CreateRideFormState> emit,
  ) {
    final next = event.vehicleClass == VehicleClass.van
        ? state.copyWith(
            estimateVan: event.estimate,
            clearEstimateVan: event.estimate == null,
          )
        : state.copyWith(
            estimateBusiness: event.estimate,
            clearEstimateBusiness: event.estimate == null,
          );
    // The two vehicle classes are estimated in parallel; flag "unavailable" only
    // once neither class produced an estimate, so the UI can explain the missing
    // price instead of showing a silent "—".
    emit(
      next.copyWith(
        estimateUnavailable:
            next.estimateBusiness == null && next.estimateVan == null,
      ),
    );
  }

  CreateRideFormState _checkAirportTransfer(CreateRideFormState currentState) {
    final from = currentState.fromAddress.toLowerCase();
    final to = currentState.toAddress.toLowerCase();

    final hasAirport =
        from.contains('airport') ||
        from.contains('muc') ||
        to.contains('airport') ||
        to.contains('muc');

    if (hasAirport && !currentState.isAirportTransfer) {
      return currentState.copyWith(
        isAirportTransfer: true,
        isArrival: from.contains('airport') || from.contains('muc'),
      );
    }

    return currentState;
  }
}
