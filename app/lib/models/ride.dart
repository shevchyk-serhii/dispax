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
  final String? flightNumber;
  final DateTime? flightTime;
  final bool isAirportTransfer;
  final bool isArrival; // true = прилет, false = отлет
  final String? gate;
  final String? terminal;
  final String? flightStatus; // "On Time", "Delayed", "Cancelled"

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
    this.flightNumber,
    this.flightTime,
    this.isAirportTransfer = false,
    this.isArrival = false,
    this.gate,
    this.terminal,
    this.flightStatus,
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
      flightNumber: json['flightNumber'],
      flightTime: json['flightTime'] != null ? DateTime.parse(json['flightTime']) : null,
      isAirportTransfer: json['isAirportTransfer'] ?? false,
      isArrival: json['isArrival'] ?? false,
      gate: json['gate'],
      terminal: json['terminal'],
      flightStatus: json['flightStatus'],
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
      'flightNumber': flightNumber,
      'flightTime': flightTime?.toIso8601String(),
      'isAirportTransfer': isAirportTransfer,
      'isArrival': isArrival,
      'gate': gate,
      'terminal': terminal,
      'flightStatus': flightStatus,
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
    String? flightNumber,
    DateTime? flightTime,
    bool? isAirportTransfer,
    bool? isArrival,
    String? gate,
    String? terminal,
    String? flightStatus,
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
      flightNumber: flightNumber ?? this.flightNumber,
      flightTime: flightTime ?? this.flightTime,
      isAirportTransfer: isAirportTransfer ?? this.isAirportTransfer,
      isArrival: isArrival ?? this.isArrival,
      gate: gate ?? this.gate,
      terminal: terminal ?? this.terminal,
      flightStatus: flightStatus ?? this.flightStatus,
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
    return 'Ride(id: $id, from: $from, to: $to, status: ${status.value}, pickupDateTime: $pickupDateTime, flightNumber: $flightNumber, gate: $gate, isArrival: $isArrival, flightStatus: $flightStatus)';
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

  // Helper methods for flight display
  String get flightIcon {
    if (!isAirportTransfer) return '';
    return isArrival ? '✈️↓' : '✈️↑';
  }

  String get flightTypeText {
    if (!isAirportTransfer) return '';
    return isArrival ? 'Arrival' : 'Departure';
  }

  String get flightStatusIcon {
    if (flightStatus == null) return '';
    switch (flightStatus!.toLowerCase()) {
      case 'on time':
        return '✅';
      case 'delayed':
        return '⏰';
      case 'cancelled':
        return '❌';
      default:
        return '❓';
    }
  }

  String get fullFlightInfo {
    if (!isAirportTransfer || flightNumber == null) return '';
    
    List<String> parts = [];
    parts.add('$flightIcon $flightNumber');
    
    if (gate != null && terminal != null) {
      parts.add('Gate $gate (Terminal $terminal)');
    } else if (gate != null) {
      parts.add('Gate $gate');
    } else if (terminal != null) {
      parts.add('Terminal $terminal');
    }
    
    if (flightStatus != null) {
      parts.add('$flightStatusIcon $flightStatus');
    }
    
    return parts.join(' • ');
  }
}
