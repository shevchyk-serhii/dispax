import 'package:equatable/equatable.dart';

abstract class CreateRideFormEvent extends Equatable {
  const CreateRideFormEvent();

  @override
  List<Object?> get props => [];
}

class ClientNameChanged extends CreateRideFormEvent {
  final String clientName;

  const ClientNameChanged(this.clientName);

  @override
  List<Object?> get props => [clientName];
}

class ClientSelected extends CreateRideFormEvent {
  final String clientId;
  final String clientName;

  const ClientSelected({required this.clientId, required this.clientName});

  @override
  List<Object?> get props => [clientId, clientName];
}

class FromAddressChanged extends CreateRideFormEvent {
  final String fromAddress;

  const FromAddressChanged(this.fromAddress);

  @override
  List<Object?> get props => [fromAddress];
}

class ToAddressChanged extends CreateRideFormEvent {
  final String toAddress;

  const ToAddressChanged(this.toAddress);

  @override
  List<Object?> get props => [toAddress];
}

class FlightNumberChanged extends CreateRideFormEvent {
  final String flightNumber;

  const FlightNumberChanged(this.flightNumber);

  @override
  List<Object?> get props => [flightNumber];
}

class PickupDateTimeChanged extends CreateRideFormEvent {
  final DateTime pickupDateTime;

  const PickupDateTimeChanged(this.pickupDateTime);

  @override
  List<Object?> get props => [pickupDateTime];
}

class AirportTransferToggled extends CreateRideFormEvent {
  final bool isAirportTransfer;

  const AirportTransferToggled(this.isAirportTransfer);

  @override
  List<Object?> get props => [isAirportTransfer];
}

class ArrivalToggled extends CreateRideFormEvent {
  final bool isArrival;

  const ArrivalToggled(this.isArrival);

  @override
  List<Object?> get props => [isArrival];
}

class GateSelected extends CreateRideFormEvent {
  final String? gate;

  const GateSelected(this.gate);

  @override
  List<Object?> get props => [gate];
}

class TerminalSelected extends CreateRideFormEvent {
  final String? terminal;

  const TerminalSelected(this.terminal);

  @override
  List<Object?> get props => [terminal];
}

class NotesChanged extends CreateRideFormEvent {
  final String notes;

  const NotesChanged(this.notes);

  @override
  List<Object?> get props => [notes];
}

class SpecialRequirementToggled extends CreateRideFormEvent {
  final String requirement;

  const SpecialRequirementToggled(this.requirement);

  @override
  List<Object?> get props => [requirement];
}

class NotesToggled extends CreateRideFormEvent {
  const NotesToggled();
}

class FormCleared extends CreateRideFormEvent {
  const FormCleared();
}

class FormSubmitted extends CreateRideFormEvent {
  const FormSubmitted();
}
