import '../../core/models/location.dart';

/// Simplified request model that matches what the backend actually uses
/// Backend converts this via CreateRideApiRequest.toDomain() which only uses:
/// - clientId (overridden by auth token)
/// - from -> pickupLocation
/// - to -> dropoffLocation
/// - pickupDateTime -> scheduledTime
/// - flightNumber
/// - isAirportTransfer
class CreateRideRequest {
  final String clientId;        // Required by API, but overridden by backend auth
  final String creatorId;       // Required by API, but ignored by backend
  final String companyId;       // Required by API, but ignored by backend
  final DateTime pickupDateTime;
  final Location from;
  final Location to;
  final String clientName;      // Required by API, but ignored by backend
  final String? flightNumber;
  final bool isAirportTransfer;
  final String? notes;
  final List<String>? specialRequirements;

  const CreateRideRequest({
    required this.clientId,
    required this.creatorId,
    required this.companyId,
    required this.pickupDateTime,
    required this.from,
    required this.to,
    required this.clientName,
    this.flightNumber,
    this.isAirportTransfer = false,
    this.notes,
    this.specialRequirements,
  });

  Map<String, dynamic> toJson() {
    return {
      'clientId': clientId,
      'creatorId': creatorId,
      'companyId': companyId,
      'pickupDateTime': pickupDateTime.toUtc().toIso8601String(),
      'from': from.toJson(),
      'to': to.toJson(),
      'status': 'Requested',
      'clientName': clientName,
      'flightNumber': flightNumber,
      'isAirportTransfer': isAirportTransfer,
      'notes': notes,
      'specialRequirements': specialRequirements,
    };
  }

  @override
  String toString() {
    return 'CreateRideRequest(clientId: $clientId, from: ${from.address}, to: ${to.address}, pickupDateTime: $pickupDateTime, flightNumber: $flightNumber, isAirportTransfer: $isAirportTransfer)';
  }
}
