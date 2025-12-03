import '../models/ride.dart';
import '../models/location.dart';

class MockRideService {
  static final List<Ride> mockRides = [
    Ride(
      id: 1,
      clientId: 2,
      creatorId: 3,
      driverId: 1,
      companyId: 1,
      pickupDateTime: DateTime.now().add(const Duration(hours: 2)),
      from: const Location(address: 'Downtown Kiev'),
      to: const Location(address: 'Boryspil Airport'),
      status: RideStatus.assigned,
      clientName: 'John Smith',
    ),
    Ride(
      id: 2,
      clientId: 2,
      creatorId: 3,
      companyId: 1,
      pickupDateTime: DateTime.now().add(const Duration(hours: 5)),
      from: const Location(address: 'Railway Station'),
      to: const Location(address: 'Kiev National University'),
      status: RideStatus.requested,
      clientName: 'Alice Johnson',
    ),
    Ride(
      id: 3,
      clientId: 2,
      creatorId: 4,
      driverId: 1,
      companyId: 1,
      pickupDateTime: DateTime.now().add(const Duration(days: 1)),
      from: const Location(address: 'Independence Square'),
      to: const Location(address: 'Golden Gate'),
      status: RideStatus.inProgress,
      clientName: 'Bob Wilson',
    ),
  ];

  static int nextId = 4;

  Future<List<Ride>> getAllRides() async {
    await Future.delayed(
      const Duration(milliseconds: 500),
    ); // Simulate network delay
    return List.from(mockRides);
  }

  Future<Ride?> getRideById(int id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return mockRides.where((ride) => ride.id == id).firstOrNull;
  }

  Future<Ride> createRide(Ride ride) async {
    await Future.delayed(const Duration(milliseconds: 800));
    final newRide = ride.copyWith(id: nextId++);
    mockRides.add(newRide);
    return newRide;
  }

  Future<Ride?> updateRide(int id, Ride ride) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final index = mockRides.indexWhere((r) => r.id == id);
    if (index != -1) {
      final updatedRide = ride.copyWith(id: id);
      mockRides[index] = updatedRide;
      return updatedRide;
    }
    return null;
  }

  Future<bool> deleteRide(int id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final index = mockRides.indexWhere((r) => r.id == id);
    if (index != -1) {
      mockRides.removeAt(index);
      return true;
    }
    return false;
  }

  void dispose() {
    // Nothing to dispose for mock service
  }
}
