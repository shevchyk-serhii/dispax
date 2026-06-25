import 'package:flutter_bloc/flutter_bloc.dart';
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
    on<SpecialRequirementToggled>(_onSpecialRequirementToggled);
    on<FormCleared>(_onFormCleared);
    on<FormSubmitted>(_onFormSubmitted);
    on<SubmissionFailed>(_onSubmissionFailed);
    on<AddressesSwapped>(_onAddressesSwapped);
    on<NewClientModeToggled>(_onNewClientModeToggled);
    on<NewClientPhoneChanged>(_onNewClientPhoneChanged);
    on<VehicleClassSelected>(_onVehicleClassSelected);
    on<ScheduleModeToggled>(_onScheduleModeToggled);
    on<EstimateReceived>(_onEstimateReceived);
  }

  void _onNotesToggled(NotesToggled event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(showNotes: !state.showNotes));
  }

  void _onNotesChanged(NotesChanged event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(notes: event.notes));
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
      emit(
        state.copyWith(
          isAirportTransfer: false,
          flightNumber: '',
          selectedGate: null,
          selectedTerminal: null,
          isArrival: false,
        ),
      );
    } else {
      emit(state.copyWith(isAirportTransfer: true));
    }
  }

  void _onArrivalToggled(
    ArrivalToggled event,
    Emitter<CreateRideFormState> emit,
  ) {
    emit(state.copyWith(isArrival: event.isArrival));
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
