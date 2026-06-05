import 'package:flutter_bloc/flutter_bloc.dart';
import 'create_ride_form_event.dart';
import 'create_ride_form_state.dart';

class CreateRideFormBloc extends Bloc<CreateRideFormEvent, CreateRideFormState> {
  CreateRideFormBloc() : super(CreateRideFormState.initial()) {
    on<ClientNameChanged>(_onClientNameChanged);
    on<ClientSelected>(_onClientSelected);
    on<DriverSelected>(_onDriverSelected);
    on<FromAddressChanged>(_onFromAddressChanged);
    on<ToAddressChanged>(_onToAddressChanged);
    on<FlightNumberChanged>(_onFlightNumberChanged);
    on<PickupDateTimeChanged>(_onPickupDateTimeChanged);
    on<AirportTransferToggled>(_onAirportTransferToggled);
    on<ArrivalToggled>(_onArrivalToggled);
    on<GateSelected>(_onGateSelected);
    on<TerminalSelected>(_onTerminalSelected);
    on<NotesToggled>(_onNotesToggled);
    on<NotesChanged>(_onNotesChanged);
    on<SpecialRequirementToggled>(_onSpecialRequirementToggled);
    on<FormCleared>(_onFormCleared);
    on<FormSubmitted>(_onFormSubmitted);
    on<AddressesSwapped>(_onAddressesSwapped);
    on<NewClientModeToggled>(_onNewClientModeToggled);
    on<NewClientPhoneChanged>(_onNewClientPhoneChanged);
  }

  void _onNotesToggled(NotesToggled event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(showNotes: !state.showNotes));
  }

  void _onNotesChanged(NotesChanged event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(notes: event.notes));
  }

  void _onSpecialRequirementToggled(SpecialRequirementToggled event, Emitter<CreateRideFormState> emit) {
    final current = List<String>.from(state.specialRequirements);
    if (current.contains(event.requirement)) {
      current.remove(event.requirement);
    } else {
      current.add(event.requirement);
    }
    emit(state.copyWith(specialRequirements: current));
  }

  void _onClientNameChanged(ClientNameChanged event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(clientName: event.clientName));
  }

  void _onClientSelected(ClientSelected event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(selectedClientId: event.clientId, clientName: event.clientName));
  }

  void _onDriverSelected(DriverSelected event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(selectedDriverId: event.driverId, clearDriverId: event.driverId == null));
  }

  void _onFromAddressChanged(FromAddressChanged event, Emitter<CreateRideFormState> emit) {
    final newState = state.copyWith(fromAddress: event.fromAddress);
    emit(_checkAirportTransfer(newState));
  }

  void _onToAddressChanged(ToAddressChanged event, Emitter<CreateRideFormState> emit) {
    final newState = state.copyWith(toAddress: event.toAddress);
    emit(_checkAirportTransfer(newState));
  }

  void _onFlightNumberChanged(FlightNumberChanged event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(flightNumber: event.flightNumber));
  }

  void _onPickupDateTimeChanged(PickupDateTimeChanged event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(pickupDateTime: event.pickupDateTime));
  }

  void _onAirportTransferToggled(AirportTransferToggled event, Emitter<CreateRideFormState> emit) {
    if (!event.isAirportTransfer) {
      emit(state.copyWith(
        isAirportTransfer: false,
        flightNumber: '',
        selectedGate: null,
        selectedTerminal: null,
        isArrival: false,
      ));
    } else {
      emit(state.copyWith(isAirportTransfer: true));
    }
  }

  void _onArrivalToggled(ArrivalToggled event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(isArrival: event.isArrival));
  }

  void _onGateSelected(GateSelected event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(selectedGate: event.gate));
  }

  void _onTerminalSelected(TerminalSelected event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(selectedTerminal: event.terminal));
  }

  void _onFormCleared(FormCleared event, Emitter<CreateRideFormState> emit) {
    emit(CreateRideFormState.initial());
  }

  void _onAddressesSwapped(AddressesSwapped event, Emitter<CreateRideFormState> emit) {
    final newState = state.copyWith(
      fromAddress: state.toAddress,
      toAddress: state.fromAddress,
    );
    emit(_checkAirportTransfer(newState));
  }

  void _onNewClientModeToggled(NewClientModeToggled event, Emitter<CreateRideFormState> emit) {
    if (state.isNewClient) {
      // Возврат к поиску — сбрасываем поля нового клиента
      emit(state.copyWith(
        isNewClient: false,
        newClientPhone: '',
        clientName: '',
        clearClientId: true,
      ));
    } else {
      // Переход к созданию нового клиента — сбрасываем выбранного
      emit(state.copyWith(
        isNewClient: true,
        clearClientId: true,
        clientName: '',
      ));
    }
  }

  void _onNewClientPhoneChanged(NewClientPhoneChanged event, Emitter<CreateRideFormState> emit) {
    emit(state.copyWith(newClientPhone: event.phone));
  }

  void _onFormSubmitted(FormSubmitted event, Emitter<CreateRideFormState> emit) {
    if (state.isValid) {
      emit(state.copyWith(status: CreateRideFormStatus.submitting));
    }
  }

  CreateRideFormState _checkAirportTransfer(CreateRideFormState currentState) {
    final from = currentState.fromAddress.toLowerCase();
    final to = currentState.toAddress.toLowerCase();

    final hasAirport = from.contains('airport') ||
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
