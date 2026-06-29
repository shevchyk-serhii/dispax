import 'package:equatable/equatable.dart';
import '../../modules/ride_management/models/payment_method.dart';
import '../../modules/ride_management/models/vehicle_class.dart';
import '../../modules/ride_management/models/ride_estimate.dart';

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
  final String? defaultAddress;

  const ClientSelected({
    required this.clientId,
    required this.clientName,
    this.defaultAddress,
  });

  @override
  List<Object?> get props => [clientId, clientName, defaultAddress];
}

/// Automatic preselect of the current user as the client (driver/client roles
/// book for themselves by default). Updates the baseline so it does NOT count as
/// a user modification.
class ClientPreselected extends CreateRideFormEvent {
  final String clientId;
  final String clientName;

  const ClientPreselected({required this.clientId, required this.clientName});

  @override
  List<Object?> get props => [clientId, clientName];
}

class ClientCleared extends CreateRideFormEvent {
  const ClientCleared();
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

/// Emitted when the operator explicitly sets or clears a manual pickup time.
/// For airport departure rides a null value means "compute automatically".
class ManualPickupTimeChanged extends CreateRideFormEvent {
  final DateTime? pickupDateTime;

  const ManualPickupTimeChanged(this.pickupDateTime);

  @override
  List<Object?> get props => [pickupDateTime];
}

/// Emitted when the flight departure date-time changes (airport departure rides only).
class FlightDepartureTimeChanged extends CreateRideFormEvent {
  final DateTime? flightDepartureTime;

  const FlightDepartureTimeChanged(this.flightDepartureTime);

  @override
  List<Object?> get props => [flightDepartureTime];
}

// Legacy alias kept for backward compatibility with any existing usages that
// reference PickupDateTimeChanged. New code should use ManualPickupTimeChanged.
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

/// Emitted when the operator types or clears the ride price. A null/empty input
/// clears the price (the ride is then created without one).
class RidePriceChanged extends CreateRideFormEvent {
  final double? price;

  const RidePriceChanged(this.price);

  @override
  List<Object?> get props => [price];
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

/// Adds a free-form tag. The bloc normalizes (trim/collapse) and ignores blanks
/// and case-insensitive duplicates so the UI matches the backend's de-dup.
class TagAdded extends CreateRideFormEvent {
  final String tag;

  const TagAdded(this.tag);

  @override
  List<Object?> get props => [tag];
}

/// Removes a tag (exact match against the stored, normalized value).
class TagRemoved extends CreateRideFormEvent {
  final String tag;

  const TagRemoved(this.tag);

  @override
  List<Object?> get props => [tag];
}

class FormCleared extends CreateRideFormEvent {
  const FormCleared();
}

class DriverSelected extends CreateRideFormEvent {
  final String? driverId;

  const DriverSelected(this.driverId);

  @override
  List<Object?> get props => [driverId];
}

/// Automatic preselect of the current user as the driver. Updates the baseline
/// so it does NOT count as a user modification.
class DriverPreselected extends CreateRideFormEvent {
  final String driverId;

  const DriverPreselected(this.driverId);

  @override
  List<Object?> get props => [driverId];
}

class FormSubmitted extends CreateRideFormEvent {
  const FormSubmitted();
}

/// Emitted when the backend rejects a submission (validation/server error).
/// Moves the form out of the submitting state so the "Create Ride" button
/// re-enables and the user can fix the offending field and retry.
class SubmissionFailed extends CreateRideFormEvent {
  const SubmissionFailed();
}

class AddressesSwapped extends CreateRideFormEvent {
  const AddressesSwapped();
}

class NewClientModeToggled extends CreateRideFormEvent {
  const NewClientModeToggled();
}

/// Toggles the "without client (from chat)" / provisional-client mode.
/// When enabled, the client search is hidden and no client is required.
class ProvisionalClientModeToggled extends CreateRideFormEvent {
  const ProvisionalClientModeToggled();
}

class NewClientPhoneChanged extends CreateRideFormEvent {
  final String phone;
  const NewClientPhoneChanged(this.phone);

  @override
  List<Object?> get props => [phone];
}

/// Emitted when the user picks a vehicle class on the client booking flow.
class VehicleClassSelected extends CreateRideFormEvent {
  final VehicleClass vehicleClass;

  const VehicleClassSelected(this.vehicleClass);

  @override
  List<Object?> get props => [vehicleClass];
}

/// Emitted when the operator selects a payment method in the create-ride form.
class PaymentMethodSelected extends CreateRideFormEvent {
  final PaymentMethod paymentMethod;

  const PaymentMethodSelected(this.paymentMethod);

  @override
  List<Object?> get props => [paymentMethod];
}

/// Emitted when the user toggles the scheduled/now toggle on the client booking flow.
class ScheduleModeToggled extends CreateRideFormEvent {
  /// true = scheduled (user picks date/time), false = ASAP / Now.
  final bool scheduled;

  const ScheduleModeToggled({required this.scheduled});

  @override
  List<Object?> get props => [scheduled];
}

/// Emitted when an estimate response arrives for a given vehicle class.
class EstimateReceived extends CreateRideFormEvent {
  final VehicleClass vehicleClass;
  final RideEstimate? estimate;

  const EstimateReceived({required this.vehicleClass, this.estimate});

  @override
  List<Object?> get props => [vehicleClass, estimate];
}
