import '../../core/models/location.dart';

/// Read-only ride state exposed to a guest via a public tracking link. Mirrors the backend `PublicRideDto`: it
/// deliberately carries NO driver/client identity, no phone, no rating, and no price — only what a guest needs to see
/// the trip move on a map.
class PublicRide {
  final String status;
  final Location pickup;
  final Location dropoff;
  final double? driverLatitude;
  final double? driverLongitude;
  final int? etaMinutes;
  final bool driverAssigned;

  const PublicRide({
    required this.status,
    required this.pickup,
    required this.dropoff,
    this.driverLatitude,
    this.driverLongitude,
    this.etaMinutes,
    required this.driverAssigned,
  });

  bool get hasDriverLocation =>
      driverLatitude != null && driverLongitude != null;

  factory PublicRide.fromJson(Map<String, dynamic> json) {
    final driverLoc = json['driverLocation'] as Map<String, dynamic>?;
    return PublicRide(
      status: json['status'] as String? ?? 'Requested',
      pickup: Location.fromJson(
        json['pickup'] as Map<String, dynamic>? ?? const {},
      ),
      dropoff: Location.fromJson(
        json['dropoff'] as Map<String, dynamic>? ?? const {},
      ),
      driverLatitude: (driverLoc?['latitude'] as num?)?.toDouble(),
      driverLongitude: (driverLoc?['longitude'] as num?)?.toDouble(),
      etaMinutes: (json['etaMinutes'] as num?)?.toInt(),
      driverAssigned: json['driverAssigned'] as bool? ?? false,
    );
  }

  PublicRide copyWith({
    String? status,
    double? driverLatitude,
    double? driverLongitude,
    int? etaMinutes,
    bool? driverAssigned,
  }) => PublicRide(
    status: status ?? this.status,
    pickup: pickup,
    dropoff: dropoff,
    driverLatitude: driverLatitude ?? this.driverLatitude,
    driverLongitude: driverLongitude ?? this.driverLongitude,
    etaMinutes: etaMinutes ?? this.etaMinutes,
    driverAssigned: driverAssigned ?? this.driverAssigned,
  );
}
