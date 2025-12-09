import 'package:flutter/material.dart';
import '../modules/flight_management/services/flight_service.dart';

class FlightScreen extends StatefulWidget {
  const FlightScreen({Key? key}) : super(key: key);

  @override
  State<FlightScreen> createState() => _FlightScreenState();
}

class _FlightScreenState extends State<FlightScreen>
    with SingleTickerProviderStateMixin {
  final FlightService _flightService = FlightService();
  late TabController _tabController;
  List<FlightData> _arrivals = [];
  List<FlightData> _departures = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFlights();
  }

  Future<void> _loadFlights() async {
    setState(() => _isLoading = true);

    try {
      final futures = await Future.wait([
        _flightService.getMunichArrivals(hours: 2),
        _flightService.getMunichDepartures(hours: 2),
      ]);

      setState(() {
        _arrivals = futures[0];
        _departures = futures[1];
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading flights: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Munich Airport'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Arrivals', icon: Icon(Icons.flight_land)),
            Tab(text: 'Departures', icon: Icon(Icons.flight_takeoff)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFlights),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFlightList(_arrivals, isArrival: true),
                _buildFlightList(_departures, isArrival: false),
              ],
            ),
    );
  }

  Widget _buildFlightList(List<FlightData> flights, {required bool isArrival}) {
    if (flights.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isArrival ? Icons.flight_land : Icons.flight_takeoff,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No ${isArrival ? 'arrivals' : 'departures'} found',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFlights,
      child: ListView.builder(
        itemCount: flights.length,
        itemBuilder: (context, index) {
          final flight = flights[index];
          return _buildFlightCard(flight, isArrival);
        },
      ),
    );
  }

  Widget _buildFlightCard(FlightData flight, bool isArrival) {
    final time = isArrival ? flight.arrivalTime : flight.departureTime;
    final airport = isArrival
        ? flight.estDepartureAirport
        : flight.estArrivalAirport;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isArrival ? Colors.green : Colors.blue,
          child: Icon(
            isArrival ? Icons.flight_land : Icons.flight_takeoff,
            color: Colors.white,
          ),
        ),
        title: Text(
          flight.callsign.trim().isNotEmpty
              ? flight.callsign.trim()
              : flight.icao24,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(airport.isNotEmpty ? airport : 'Unknown'),
        trailing: Text(
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}
