import 'location.dart';

enum RideStatus {
  requested('Requested'),
  assigned('Assigned'),
  inProgress('InProgress'),
  completed('Completed'),
  cancelled('Cancelled');

  const RideStatus(this.value);
  final String value;

  static RideStatus fromString(String value) {
    return RideStatus.values.firstWhere(
      (status) => status.value.toLowerCase() == value.toLowerCase(),
      orElse: () => RideStatus.requested,
    );
  }
}

class Ride {
  final int id;
  final int clientId;
  final int creatorId;
  final int? driverId;
  final int companyId;
  final int? scheduleDayId;
  final DateTime pickupDateTime;
  final Location from;
  final Location to;
  final RideStatus status;
  final String clientName;

  const Ride({
    required this.id,
    required this.clientId,
    required this.creatorId,
    this.driverId,
    required this.companyId,
    this.scheduleDayId,
    required this.pickupDateTime,
    required this.from,
    required this.to,
    this.status = RideStatus.requested,
    required this.clientName,
  });

  factory Ride.fromJson(Map<String, dynamic> json) {
    return Ride(
      id: json['id'] ?? 0,
      clientId: json['clientId'] ?? 0,
      creatorId: json['creatorId'] ?? 0,
      driverId: json['driverId'],
      companyId: json['companyId'] ?? 0,
      scheduleDayId: json['scheduleDayId'],
      pickupDateTime: DateTime.parse(json['pickupDateTime']),
      from: Location.fromJson(json['from']),
      to: Location.fromJson(json['to']),
      status: RideStatus.fromString(json['status'] ?? 'Requested'),
      clientName: json['clientName'] ?? 'Unknown Client',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientId': clientId,
      'creatorId': creatorId,
      'driverId': driverId,
      'companyId': companyId,
      'scheduleDayId': scheduleDayId,
      'pickupDateTime': pickupDateTime.toIso8601String(),
      'from': from.toJson(),
      'to': to.toJson(),
      'status': status.value,
      'clientName': clientName,
    };
  }

  Ride copyWith({
    int? id,
    int? clientId,
    int? creatorId,
    int? driverId,
    int? companyId,
    int? scheduleDayId,
    DateTime? pickupDateTime,
    Location? from,
    Location? to,
    RideStatus? status,
    String? clientName,
  }) {
    return Ride(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      creatorId: creatorId ?? this.creatorId,
      driverId: driverId ?? this.driverId,
      companyId: companyId ?? this.companyId,
      scheduleDayId: scheduleDayId ?? this.scheduleDayId,
      pickupDateTime: pickupDateTime ?? this.pickupDateTime,
      from: from ?? this.from,
      to: to ?? this.to,
      status: status ?? this.status,
      clientName: clientName ?? this.clientName,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Ride &&
        other.id == id &&
        other.clientId == clientId &&
        other.status == status &&
        other.pickupDateTime == pickupDateTime &&
        other.from == from &&
        other.to == to;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        clientId.hashCode ^
        status.hashCode ^
        pickupDateTime.hashCode ^
        from.hashCode ^
        to.hashCode;
  }

  @override
  String toString() {
    return 'Ride(id: $id, from: $from, to: $to, status: ${status.value}, pickupDateTime: $pickupDateTime)';
  }

  String get statusDisplayName {
    switch (status) {
      case RideStatus.requested:
        return 'Requested';
      case RideStatus.assigned:
        return 'Assigned';
      case RideStatus.inProgress:
        return 'In Progress';
      case RideStatus.completed:
        return 'Completed';
      case RideStatus.cancelled:
        return 'Cancelled';
    }
  }
}
