class WebSocketEvent {
  final String type;
  final String? rideId;
  final String? driverId;
  final String? clientId;
  final String? newStatus;
  final String? cancellationReason;
  final double? latitude;
  final double? longitude;
  final String? locationType;
  final String companyId;
  final Map<String, dynamic> data;

  const WebSocketEvent({
    required this.type,
    this.rideId,
    this.driverId,
    this.clientId,
    this.newStatus,
    this.cancellationReason,
    this.latitude,
    this.longitude,
    this.locationType,
    required this.companyId,
    this.data = const {},
  });

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    // ZIO JSON encodes sealed traits as {"TypeName": {payload}}
    final type = json.keys.firstWhere(
      (k) => k != 'type',
      orElse: () => json['type'] ?? '',
    );
    final payload = (json[type] is Map<String, dynamic>)
        ? json[type] as Map<String, dynamic>
        : json;

    return WebSocketEvent(
      type: type,
      rideId: payload['rideId'],
      // LocationUpdated uses 'userId' for the driver id
      driverId: payload['driverId'] ?? payload['userId'],
      clientId: payload['clientId'],
      newStatus: payload['newStatus'],
      cancellationReason: payload['cancellationReason'] as String?,
      latitude: payload['latitude']?.toDouble(),
      longitude: payload['longitude']?.toDouble(),
      locationType: payload['locationType'],
      companyId: payload['companyId'] ?? '',
      data: payload,
    );
  }

  bool get isRideStatusChanged => type == 'RideStatusChanged';
  bool get isRideAssigned => type == 'RideAssigned';
  bool get isRideCreated => type == 'RideCreated';
  bool get isLocationUpdated => type == 'LocationUpdated';
  bool get isChatMessage => type == 'ChatMessageSent';
  bool get isGeofenceTriggered => type == 'GeofenceTriggered';
  bool get isDriverApproaching => type == 'DriverApproaching';
  bool get isPoolUpdate =>
      type == 'RideStatusChanged' && data['newStatus'] == 'PooledRide';
  bool get isAirportCheckpointReached => type == 'AirportCheckpointReached';
  bool get isEtaAtRisk => type == 'EtaAtRisk';
  bool get isRideDetailsUpdated => type == 'RideDetailsUpdated';
  bool get isRideConfirmed => type == 'RideConfirmed';
  bool get isRideRejected => type == 'RideRejected';

  String? get geofenceName => data['geofenceName'];
  String? get alertType => data['alertType'];
  int? get distanceMeters => data['distanceMeters'];
  int? get threshold => data['threshold'];
  String? get checkpointType => data['checkpointType'];
  String? get checkpointName => data['checkpointName'];

  // RideRejected event accessors
  String? get rejectionReason => data['reason'] as String?;

  // EtaAtRisk event accessors
  String? get etaRiskDriverId => data['driverId'] as String?;
  int? get etaMinutes => (data['etaMinutes'] as num?)?.toInt();
  int? get pickupInMinutes => (data['minutesUntilPickup'] as num?)?.toInt();
  int? get slackMinutes => (data['slackMinutes'] as num?)?.toInt();
}
