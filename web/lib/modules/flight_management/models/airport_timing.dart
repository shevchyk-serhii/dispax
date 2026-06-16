import 'package:equatable/equatable.dart';

class AirportTiming extends Equatable {
  final DateTime optimalEntryTime;

  final DateTime latestEntryTime;

  final Duration travelTime;

  final Duration bufferTime;

  final double optimalParkingCost;

  final double earlyEntryParkingCost;

  final double savings;

  final String flightStatus;

  final DateTime? actualArrivalTime;

  final Duration timeToDepart;

  const AirportTiming({
    required this.optimalEntryTime,
    required this.latestEntryTime,
    required this.travelTime,
    required this.bufferTime,
    required this.optimalParkingCost,
    required this.earlyEntryParkingCost,
    required this.savings,
    required this.flightStatus,
    this.actualArrivalTime,
    required this.timeToDepart,
  });

  factory AirportTiming.fromJson(Map<String, dynamic> json) {
    return AirportTiming(
      optimalEntryTime: DateTime.parse(json['optimalEntryTime']),
      latestEntryTime: DateTime.parse(json['latestEntryTime']),
      travelTime: Duration(minutes: json['travelTimeMinutes']),
      bufferTime: Duration(minutes: json['bufferTimeMinutes']),
      optimalParkingCost: (json['optimalParkingCost'] as num).toDouble(),
      earlyEntryParkingCost: (json['earlyEntryParkingCost'] as num).toDouble(),
      savings: (json['savings'] as num).toDouble(),
      flightStatus: json['flightStatus'],
      actualArrivalTime: json['actualArrivalTime'] != null
          ? DateTime.parse(json['actualArrivalTime'])
          : null,
      timeToDepart: Duration(minutes: json['timeToDepartMinutes']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'optimalEntryTime': optimalEntryTime.toIso8601String(),
      'latestEntryTime': latestEntryTime.toIso8601String(),
      'travelTimeMinutes': travelTime.inMinutes,
      'bufferTimeMinutes': bufferTime.inMinutes,
      'optimalParkingCost': optimalParkingCost,
      'earlyEntryParkingCost': earlyEntryParkingCost,
      'savings': savings,
      'flightStatus': flightStatus,
      'actualArrivalTime': actualArrivalTime?.toIso8601String(),
      'timeToDepartMinutes': timeToDepart.inMinutes,
    };
  }

  bool get shouldDepartNow => timeToDepart.inMinutes <= 0;

  bool get isCritical => timeToDepart.inMinutes <= 15;

  bool get isFlightDelayed => flightStatus.toLowerCase().contains('delay');

  String get formattedSavings => '€${savings.toStringAsFixed(2)}';

  String get formattedTimeToDepart {
    if (shouldDepartNow) return 'Depart now!';

    final hours = timeToDepart.inHours;
    final minutes = timeToDepart.inMinutes % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String get formattedOptimalEntryTime {
    final hour = optimalEntryTime.hour.toString().padLeft(2, '0');
    final minute = optimalEntryTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  List<Object?> get props => [
    optimalEntryTime,
    latestEntryTime,
    travelTime,
    bufferTime,
    optimalParkingCost,
    earlyEntryParkingCost,
    savings,
    flightStatus,
    actualArrivalTime,
    timeToDepart,
  ];
}
