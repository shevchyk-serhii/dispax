import '../../core/models/location.dart';
import 'vehicle_class.dart';

/// Request model for creating a ride.
///
/// For airport **departure** transfers ([isAirportTransfer] = true, [isArrival] = false):
/// - [flightDepartureTime] carries the flight departure date-time (sent as `flightTime`).
/// - [manualPickupDateTime] is optional. When null the backend computes the pickup time
///   automatically from [flightDepartureTime] using the configured timing hierarchy.
///   When non-null the operator-supplied value is used verbatim (manual override).
///
/// For all other ride types:
/// - [manualPickupDateTime] must be non-null (the backend requires an explicit pickup time).
class CreateRideRequest {
  final String clientId; // Required by API, but overridden by backend auth
  final String creatorId; // Required by API, but ignored by backend
  final String companyId; // Required by API, but ignored by backend
  final Location from;
  final Location to;
  final String clientName; // Required by API, but ignored by backend
  final String? flightNumber;
  final bool isAirportTransfer;
  final bool isArrival;

  /// Flight departure date-time for airport departure rides. Sent as `flightTime`.
  /// Required when [isAirportTransfer] = true and [isArrival] = false.
  final DateTime? flightDepartureTime;

  /// Operator-supplied pickup time. When null for departure rides, the backend
  /// computes the pickup time automatically. For non-departure rides must be non-null.
  final DateTime? manualPickupDateTime;

  final String? notes;
  final List<String>? specialRequirements;
  final String? driverId;
  final String? newClientPhone;
  final VehicleClass vehicleClass;

  const CreateRideRequest({
    required this.clientId,
    required this.creatorId,
    required this.companyId,
    required this.from,
    required this.to,
    required this.clientName,
    this.flightNumber,
    this.isAirportTransfer = false,
    this.isArrival = false,
    this.flightDepartureTime,
    this.manualPickupDateTime,
    this.notes,
    this.specialRequirements,
    this.driverId,
    this.newClientPhone,
    this.vehicleClass = VehicleClass.business,
  });

  Map<String, dynamic> toJson() {
    final isDeparture = isAirportTransfer && !isArrival;

    return {
      'clientId': clientId,
      'creatorId': creatorId,
      'companyId': companyId,
      // For departure rides without a manual pickup time, omit pickupDateTime so
      // the backend knows to compute it from flightTime. For all other cases include it.
      if (!isDeparture || manualPickupDateTime != null)
        'pickupDateTime': manualPickupDateTime!.toUtc().toIso8601String(),
      'from': from.toJson(),
      'to': to.toJson(),
      'status': 'Requested',
      'clientName': clientName,
      if (flightNumber != null) 'flightNumber': flightNumber,
      'isAirportTransfer': isAirportTransfer,
      'isArrival': isArrival,
      if (flightDepartureTime != null)
        'flightTime': flightDepartureTime!.toUtc().toIso8601String(),
      if (notes != null) 'notes': notes,
      if (specialRequirements != null)
        'specialRequirements': specialRequirements!.join(', '),
      if (driverId != null) 'driverId': driverId,
      if (newClientPhone != null && newClientPhone!.isNotEmpty)
        'clientPhone': newClientPhone,
      'vehicleClass': vehicleClass.wire,
    };
  }

  @override
  String toString() {
    return 'CreateRideRequest(clientId: $clientId, from: ${from.address}, to: ${to.address}, '
        'manualPickupDateTime: $manualPickupDateTime, flightDepartureTime: $flightDepartureTime, '
        'flightNumber: $flightNumber, isAirportTransfer: $isAirportTransfer, isArrival: $isArrival)';
  }
}
