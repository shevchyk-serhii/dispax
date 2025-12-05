import 'package:equatable/equatable.dart';

class AirportTiming extends Equatable {
  /// Optimal airport entry time
  final DateTime optimalEntryTime;
  
  /// Latest reasonable entry time
  final DateTime latestEntryTime;
  
  /// Travel time from current location to airport
  final Duration travelTime;
  
  /// Recommended buffer time
  final Duration bufferTime;
  
  /// Parking cost with optimal entry
  final double optimalParkingCost;
  
  /// Parking cost with early entry
  final double earlyEntryParkingCost;
  
  /// Savings with optimal entry
  final double savings;
  
  /// Flight status (On Time, Delayed, etc.)
  final String flightStatus;
  
  /// Actual arrival time (if available)
  final DateTime? actualArrivalTime;
  
  /// Time until departure to airport
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

  /// Whether driver should depart now
  bool get shouldDepartNow => timeToDepart.inMinutes <= 0;

  /// Whether timing is critical
  bool get isCritical => timeToDepart.inMinutes <= 15;

  /// Whether flight is delayed
  bool get isFlightDelayed => flightStatus.toLowerCase().contains('delay');

  /// Formatted savings string
  String get formattedSavings => '€${savings.toStringAsFixed(2)}';

  /// Formatted time until departure
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

  /// Formatted optimal entry time
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