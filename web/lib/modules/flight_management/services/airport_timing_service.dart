import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../ride_management/models/ride.dart';
import '../../flight_management/models/airport_timing.dart';
import '../../core/services/api_client.dart';

class AirportTimingService {
  static AirportTimingService? _instance;
  final ApiClient _apiClient;

  AirportTimingService._internal(this._apiClient);

  static AirportTimingService get instance {
    if (_instance == null) {
      throw StateError(
        'AirportTimingService has not been configured. '
        'Call AirportTimingService.configure() with an authenticated ApiClient first.'
      );
    }
    return _instance!;
  }

  /// Configure the singleton with an authenticated ApiClient
  static void configure(ApiClient apiClient) {
    _instance = AirportTimingService._internal(apiClient);
  }

  Future<AirportTiming?> getOptimalEntryTime({
    required String rideId,
    required double driverLatitude,
    required double driverLongitude,
  }) async {
    try {
      debugPrint('🚗 Calculating optimal entry time for ride $rideId');

      final response = await _apiClient.post('/rides/$rideId/airport-timing', {
        'driverLatitude': driverLatitude,
        'driverLongitude': driverLongitude,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AirportTiming.fromJson(data);
      } else {
        debugPrint('❌ Failed to get airport timing: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error calculating airport timing: $e');
      return null;
    }
  }

  Future<bool> notifyAirportEntry({
    required String rideId,
    required DateTime entryTime,
  }) async {
    try {
      final response = await _apiClient.patch('/rides/$rideId/airport-entry', {
        'entryTime': entryTime.toIso8601String(),
        'actualEntry': true,
      });

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('❌ Error notifying airport entry: $e');
      return false;
    }
  }

  Future<AirportFlightInfo?> getFlightInfo(String flightNumber) async {
    try {
      final response = await _apiClient.get('/flights/$flightNumber');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AirportFlightInfo.fromJson(data);
      }
    } catch (e) {
      debugPrint('❌ Error getting flight info: $e');
    }
    return null;
  }

  Future<Duration?> calculateTravelTime({
    required double fromLatitude,
    required double fromLongitude,
    required String airportCode,
  }) async {
    try {
      final response = await _apiClient.post('/travel-time', {
        'fromLatitude': fromLatitude,
        'fromLongitude': fromLongitude,
        'destinationAirport': airportCode,
      });

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final minutes = data['travelTimeMinutes'] as int;
        return Duration(minutes: minutes);
      }
    } catch (e) {
      debugPrint('❌ Error calculating travel time: $e');
    }
    return null;
  }
}

class AirportFlightInfo {
  final String flightNumber;
  final DateTime scheduledTime;
  final DateTime? actualTime;
  final String status;
  final String gate;
  final String terminal;

  AirportFlightInfo({
    required this.flightNumber,
    required this.scheduledTime,
    this.actualTime,
    required this.status,
    required this.gate,
    required this.terminal,
  });

  factory AirportFlightInfo.fromJson(Map<String, dynamic> json) {
    return AirportFlightInfo(
      flightNumber: json['flightNumber'],
      scheduledTime: DateTime.parse(json['scheduledTime']),
      actualTime: json['actualTime'] != null
          ? DateTime.parse(json['actualTime'])
          : null,
      status: json['status'],
      gate: json['gate'],
      terminal: json['terminal'],
    );
  }

  DateTime get effectiveArrivalTime => actualTime ?? scheduledTime;

  Duration? get delay {
    if (actualTime == null) return null;
    return actualTime!.difference(scheduledTime);
  }
}