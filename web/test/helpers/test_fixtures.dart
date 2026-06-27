import 'package:dispax/modules/core/models/location.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/modules/schedule_management/models/schedule_day.dart';
import 'package:dispax/modules/ride_management/models/create_ride_request.dart';
import 'package:dispax/modules/ride_management/models/payment_method.dart';

class TestFixtures {
  static Location location({
    String address = '123 Main St',
    double? latitude = 48.1351,
    double? longitude = 11.5820,
  }) {
    return Location(address: address, latitude: latitude, longitude: longitude);
  }

  static Person person({
    String id = 'person-1',
    String name = 'John Doe',
    String email = 'john@example.com',
    PersonRole role = PersonRole.client,
    String? companyId = 'company-1',
    String? licenseNumber,
    String? phone = '+491234567890',
    VehicleInfo? vehicleInfo,
    String? preferredLanguage,
    bool mustChangePassword = false,
  }) {
    return Person(
      id: id,
      name: name,
      email: email,
      role: role,
      companyId: companyId,
      licenseNumber: licenseNumber,
      phone: phone,
      vehicleInfo: vehicleInfo,
      preferredLanguage: preferredLanguage,
      mustChangePassword: mustChangePassword,
    );
  }

  static Person driver({
    String id = 'driver-1',
    String name = 'Driver Hans',
    String email = 'hans@example.com',
    String? licenseNumber = 'DL-12345',
    VehicleInfo? vehicleInfo,
  }) {
    return Person(
      id: id,
      name: name,
      email: email,
      role: PersonRole.driver,
      companyId: 'company-1',
      licenseNumber: licenseNumber,
      phone: '+491111111111',
      vehicleInfo:
          vehicleInfo ?? const VehicleInfo(make: 'BMW', model: '5 Series'),
    );
  }

  static Person secretary({
    String id = 'secretary-1',
    String name = 'Secretary Anna',
    String email = 'anna@example.com',
  }) {
    return Person(
      id: id,
      name: name,
      email: email,
      role: PersonRole.secretary,
      companyId: 'company-1',
      phone: '+492222222222',
    );
  }

  static Ride ride({
    String id = 'ride-1',
    String clientId = 'client-1',
    String creatorId = 'creator-1',
    String? driverId,
    String companyId = 'company-1',
    DateTime? pickupDateTime,
    Location? from,
    Location? to,
    RideStatus status = RideStatus.requested,
    String clientName = 'Test Client',
    bool clientHasAvatar = false,
    String? flightNumber,
    DateTime? flightTime,
    DateTime? flightScheduledTime,
    bool isAirportTransfer = false,
    bool isArrival = false,
    String? gate,
    String? terminal,
    String? flightStatus,
    DateTime? optimalEntryTime,
    String? driverName,
    double? price,
    String? paymentMethod,
    List<String> tags = const [],
  }) {
    return Ride(
      id: id,
      clientId: clientId,
      creatorId: creatorId,
      driverId: driverId,
      companyId: companyId,
      pickupDateTime: pickupDateTime ?? DateTime(2026, 3, 15, 10, 0),
      from: from ?? location(address: 'Pickup St 1'),
      to: to ?? location(address: 'Dropoff St 2'),
      status: status,
      clientName: clientName,
      clientHasAvatar: clientHasAvatar,
      flightNumber: flightNumber,
      flightTime: flightTime,
      flightScheduledTime: flightScheduledTime,
      isAirportTransfer: isAirportTransfer,
      isArrival: isArrival,
      gate: gate,
      terminal: terminal,
      flightStatus: flightStatus,
      optimalEntryTime: optimalEntryTime,
      driverName: driverName,
      price: price,
      paymentMethod: paymentMethod,
      tags: tags,
    );
  }

  static Ride airportRide({
    String id = 'ride-airport',
    bool isArrival = true,
    String flightNumber = 'LH1234',
    String? gate = 'G12',
    String? terminal = 'T2',
    String? flightStatus = 'On Time',
    DateTime? optimalEntryTime,
  }) {
    return ride(
      id: id,
      isAirportTransfer: true,
      isArrival: isArrival,
      flightNumber: flightNumber,
      flightTime: DateTime(2026, 3, 15, 9, 30),
      gate: gate,
      terminal: terminal,
      flightStatus: flightStatus,
      optimalEntryTime: optimalEntryTime,
    );
  }

  static ScheduleDay scheduleDay({
    String id = 'schedule-1',
    String driverId = 'driver-1',
    String companyId = 'company-1',
    DateTime? date,
    String startTime = '08:00',
    String endTime = '17:00',
    ScheduleDayStatus status = ScheduleDayStatus.scheduled,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ScheduleDay(
      id: id,
      driverId: driverId,
      companyId: companyId,
      date: date ?? DateTime(2026, 3, 15),
      startTime: startTime,
      endTime: endTime,
      status: status,
      notes: notes,
      createdAt: createdAt ?? DateTime(2026, 3, 10),
      updatedAt: updatedAt ?? DateTime(2026, 3, 10),
    );
  }

  static CreateRideRequest createRideRequest({
    String clientId = 'client-1',
    String creatorId = 'creator-1',
    String companyId = 'company-1',
    DateTime? pickupDateTime,
    Location? from,
    Location? to,
    String clientName = 'Test Client',
    String? flightNumber,
    bool isAirportTransfer = false,
    String? driverId,
    double? price,
    PaymentMethod paymentMethod = PaymentMethod.invoice,
  }) {
    return CreateRideRequest(
      clientId: clientId,
      creatorId: creatorId,
      companyId: companyId,
      manualPickupDateTime: pickupDateTime ?? DateTime(2026, 3, 15, 10, 0),
      from: from ?? location(address: 'Pickup St'),
      to: to ?? location(address: 'Dropoff St'),
      clientName: clientName,
      flightNumber: flightNumber,
      isAirportTransfer: isAirportTransfer,
      driverId: driverId,
      price: price,
      paymentMethod: paymentMethod,
    );
  }

  static Map<String, dynamic> rideJson({
    String id = 'ride-1',
    String status = 'Requested',
  }) {
    return {
      'id': id,
      'clientId': 'client-1',
      'creatorId': 'creator-1',
      'companyId': 'company-1',
      'pickupDateTime': '2026-03-15T10:00:00.000',
      'from': {'address': 'Pickup St', 'latitude': 48.1, 'longitude': 11.5},
      'to': {'address': 'Dropoff St', 'latitude': 48.2, 'longitude': 11.6},
      'status': status,
      'clientName': 'Test Client',
      'clientHasAvatar': false,
      'isAirportTransfer': false,
      'isArrival': false,
      'driverApproaching': false,
    };
  }

  static Map<String, dynamic> scheduleDayJson({String id = 'schedule-1'}) {
    return {
      'id': id,
      'driverId': 'driver-1',
      'companyId': 'company-1',
      'date': '2026-03-15',
      'startTime': '08:00',
      'endTime': '17:00',
      'status': 'Scheduled',
      'createdAt': '2026-03-10T00:00:00.000',
      'updatedAt': '2026-03-10T00:00:00.000',
    };
  }

  static Map<String, dynamic> personJson({
    String id = 'person-1',
    String role = 'client',
  }) {
    return {
      'id': id,
      'name': 'John Doe',
      'email': 'john@example.com',
      'role': role,
      'companyId': 'company-1',
      'phone': '+491234567890',
    };
  }
}
