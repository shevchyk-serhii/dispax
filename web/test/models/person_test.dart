import 'package:flutter_test/flutter_test.dart';
import 'package:oktopus/modules/core/models/person.dart';
import '../helpers/test_fixtures.dart';

void main() {
  group('Person', () {
    test('fromJson creates Person correctly', () {
      final json = TestFixtures.personJson();
      final person = Person.fromJson(json);

      expect(person.id, 'person-1');
      expect(person.name, 'John Doe');
      expect(person.email, 'john@example.com');
      expect(person.role, PersonRole.client);
      expect(person.companyId, 'company-1');
      expect(person.phone, '+491234567890');
    });

    test('toJson produces correct map', () {
      final person = TestFixtures.person();
      final json = person.toJson();

      expect(json['id'], 'person-1');
      expect(json['name'], 'John Doe');
      expect(json['email'], 'john@example.com');
      expect(json['role'], 'client');
      expect(json['companyId'], 'company-1');
      expect(json['phone'], '+491234567890');
    });

    test('fromJson/toJson roundtrip for client', () {
      final original = TestFixtures.person(role: PersonRole.client);
      final restored = Person.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.email, original.email);
      expect(restored.role, original.role);
    });

    test('fromJson/toJson roundtrip for driver', () {
      final original = TestFixtures.driver();
      final restored = Person.fromJson(original.toJson());

      expect(restored.role, PersonRole.driver);
      expect(restored.licenseNumber, original.licenseNumber);
    });

    test('fromJson/toJson roundtrip for secretary', () {
      final original = TestFixtures.secretary();
      final restored = Person.fromJson(original.toJson());

      expect(restored.role, PersonRole.secretary);
    });

    test('fromJson/toJson roundtrip for dispatcher', () {
      final original = TestFixtures.person(role: PersonRole.dispatcher);
      final restored = Person.fromJson(original.toJson());

      expect(restored.role, PersonRole.dispatcher);
    });

    test('fromJson defaults to client for unknown role', () {
      final json = TestFixtures.personJson()..['role'] = 'unknown';
      final person = Person.fromJson(json);

      expect(person.role, PersonRole.client);
    });

    test('isDriver returns true only for driver role', () {
      expect(TestFixtures.driver().isDriver, isTrue);
      expect(TestFixtures.person().isDriver, isFalse);
    });

    test('isClient returns true only for client role', () {
      expect(TestFixtures.person(role: PersonRole.client).isClient, isTrue);
      expect(TestFixtures.driver().isClient, isFalse);
    });

    test('isSecretary returns true only for secretary role', () {
      expect(TestFixtures.secretary().isSecretary, isTrue);
      expect(TestFixtures.person().isSecretary, isFalse);
    });

    test('isDispatcher returns true only for dispatcher role', () {
      expect(TestFixtures.person(role: PersonRole.dispatcher).isDispatcher, isTrue);
      expect(TestFixtures.person().isDispatcher, isFalse);
    });

    test('missing optional fields are null', () {
      final json = {
        'id': 'p1',
        'name': 'Min',
        'email': 'min@test.com',
        'role': 'client',
      };

      final person = Person.fromJson(json);

      expect(person.companyId, isNull);
      expect(person.licenseNumber, isNull);
      expect(person.phone, isNull);
      expect(person.vehicleInfo, isNull);
    });
  });

  group('VehicleInfo', () {
    test('fromJson creates VehicleInfo correctly', () {
      final json = {
        'make': 'BMW',
        'model': '5 Series',
        'color': 'Black',
        'licensePlate': 'M-AB 1234',
        'year': 2024,
      };

      final vehicle = VehicleInfo.fromJson(json);

      expect(vehicle.make, 'BMW');
      expect(vehicle.model, '5 Series');
      expect(vehicle.color, 'Black');
      expect(vehicle.licensePlate, 'M-AB 1234');
      expect(vehicle.year, 2024);
    });

    test('toJson produces correct map', () {
      const vehicle = VehicleInfo(
        make: 'Mercedes',
        model: 'S-Class',
        color: 'Silver',
        licensePlate: 'M-CD 5678',
        year: 2025,
      );

      final json = vehicle.toJson();

      expect(json['make'], 'Mercedes');
      expect(json['model'], 'S-Class');
      expect(json['color'], 'Silver');
      expect(json['licensePlate'], 'M-CD 5678');
      expect(json['year'], 2025);
    });

    test('fromJson/toJson roundtrip', () {
      const original = VehicleInfo(make: 'Audi', model: 'A6');
      final restored = VehicleInfo.fromJson(original.toJson());

      expect(restored.make, original.make);
      expect(restored.model, original.model);
    });

    test('Person with VehicleInfo serializes correctly', () {
      final person = TestFixtures.driver(
        vehicleInfo: const VehicleInfo(
          make: 'Toyota',
          model: 'Camry',
          color: 'White',
          licensePlate: 'M-XY 9999',
          year: 2023,
        ),
      );

      final json = person.toJson();
      final restored = Person.fromJson(json);

      expect(restored.vehicleInfo, isNotNull);
      expect(restored.vehicleInfo!.make, 'Toyota');
      expect(restored.vehicleInfo!.model, 'Camry');
      expect(restored.vehicleInfo!.color, 'White');
    });
  });
}
