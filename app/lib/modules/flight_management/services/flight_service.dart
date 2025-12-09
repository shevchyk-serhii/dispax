import 'dart:convert';
import 'package:http/http.dart' as http;
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
  static String get baseUrl => '${ApiClient.privateBaseUrl}/flights/munich';

  Future<List<FlightData>> getMunichArrivals({int? hours}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final begin = now - (hours ?? 1) * 3600;

    final response = await http.get(
      Uri.parse('$baseUrl/arrivals?begin=$begin&end=$now'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((flight) => FlightData.fromJson(flight)).toList();
    } else {
      throw Exception('Failed to load arrivals');
    }
  }

  Future<List<FlightData>> getMunichDepartures({int? hours}) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final begin = now - (hours ?? 1) * 3600;

    final response = await http.get(
      Uri.parse('$baseUrl/departures?begin=$begin&end=$now'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((flight) => FlightData.fromJson(flight)).toList();
    } else {
      throw Exception('Failed to load departures');
    }
  }
}
