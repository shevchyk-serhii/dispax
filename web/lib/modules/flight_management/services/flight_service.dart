import 'dart:convert';
import '../../core/services/api_client.dart';

class FlightData {
  final String icao24;
  final int firstSeen;
  final String estDepartureAirport;
  final int lastSeen;
  final String estArrivalAirport;
  final String callsign;

  FlightData({
    required this.icao24,
    required this.firstSeen,
    required this.estDepartureAirport,
    required this.lastSeen,
    required this.estArrivalAirport,
    required this.callsign,
  });

  factory FlightData.fromJson(Map<String, dynamic> json) {
    return FlightData(
      icao24: json['icao24'] ?? '',
      firstSeen: json['firstSeen'] ?? 0,
      estDepartureAirport: json['estDepartureAirport'] ?? '',
      lastSeen: json['lastSeen'] ?? 0,
      estArrivalAirport: json['estArrivalAirport'] ?? '',
      callsign: json['callsign'] ?? '',
    );
  }

  DateTime get departureTime =>
      DateTime.fromMillisecondsSinceEpoch(firstSeen * 1000);
  DateTime get arrivalTime =>
      DateTime.fromMillisecondsSinceEpoch(lastSeen * 1000);
}

class FlightService {
  final ApiClient _apiClient;

  FlightService({ApiClient? apiClient}) : _apiClient = apiClient ?? ApiClient();

  Future<List<FlightData>> getArrivals({String airport = 'default', int? hours}) async {
    try {
      final response = await _apiClient.get('/flights/$airport/arrivals');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => FlightData.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<FlightData>> getDepartures({String airport = 'default', int? hours}) async {
    try {
      final response = await _apiClient.get('/flights/$airport/departures');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => FlightData.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<List<FlightData>> getMunichArrivals({int? hours}) async {
    return getArrivals(airport: 'munich', hours: hours);
  }

  Future<List<FlightData>> getMunichDepartures({int? hours}) async {
    return getDepartures(airport: 'munich', hours: hours);
  }
}
