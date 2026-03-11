class WebSocketEvent {
  final String type;
  final String? rideId;
  final String? driverId;
  final String? clientId;
  final String? newStatus;
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
    this.latitude,
    this.longitude,
    this.locationType,
    required this.companyId,
    this.data = const {},
  });

  factory WebSocketEvent.fromJson(Map<String, dynamic> json) {
    return WebSocketEvent(
      type: json['type'] ?? '',
      rideId: json['rideId'],
      driverId: json['driverId'],
      clientId: json['clientId'],
      newStatus: json['newStatus'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
      locationType: json['locationType'],
      companyId: json['companyId'] ?? '',
      data: json,
    );
  }

  bool get isRideStatusChanged => type == 'RideStatusChanged';
  bool get isRideAssigned => type == 'RideAssigned';
  bool get isRideCreated => type == 'RideCreated';
  bool get isLocationUpdated => type == 'LocationUpdated';
  bool get isChatMessage => type == 'ChatMessageSent';
}
