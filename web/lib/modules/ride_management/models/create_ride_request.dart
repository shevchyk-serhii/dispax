import '../../core/models/location.dart';
import 'payment_method.dart';
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

  /// Free-form operator tags. Sent as a JSON array (unlike specialRequirements,
  /// which is joined into a CSV string). Omitted from the payload when empty.
  final List<String>? tags;
  final String? driverId;
  final String? newClientPhone;
  final VehicleClass vehicleClass;

  /// Operator-selected payment method. Defaults to [PaymentMethod.invoice]
  /// (Rechnung) and is always sent to the backend.
  final PaymentMethod paymentMethod;

  /// Operator-supplied ride price (€). Optional — omitted from the payload when
  /// null, in which case the backend creates the ride without a price.
  final double? price;

  /// When true, the ride is booked "from chat" without a real client: the backend creates a
  /// lightweight provisional client (carrying [clientName]/[newClientPhone]) and books the ride
  /// onto it, to be upgraded into a real client later. [clientId] is sent empty in this mode.
  final bool provisionalClient;

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
    this.tags,
    this.driverId,
    this.newClientPhone,
    this.vehicleClass = VehicleClass.business,
    this.paymentMethod = PaymentMethod.invoice,
    this.price,
    this.provisionalClient = false,
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
      if (tags != null && tags!.isNotEmpty) 'tags': tags,
      if (driverId != null) 'driverId': driverId,
      if (newClientPhone != null && newClientPhone!.isNotEmpty)
        'clientPhone': newClientPhone,
      'vehicleClass': vehicleClass.wire,
      'paymentMethod': paymentMethod.wire,
      if (price != null) 'price': price,
      if (provisionalClient) 'provisionalClient': true,
    };
  }

  @override
  String toString() {
    return 'CreateRideRequest(clientId: $clientId, from: ${from.address}, to: ${to.address}, '
        'manualPickupDateTime: $manualPickupDateTime, flightDepartureTime: $flightDepartureTime, '
        'flightNumber: $flightNumber, isAirportTransfer: $isAirportTransfer, isArrival: $isArrival)';
  }
}
