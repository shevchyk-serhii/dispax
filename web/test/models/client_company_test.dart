import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/billing/models/client_company.dart';

void main() {
  group('ClientCompany.fromJson', () {
    Map<String, dynamic> _json({
      String? email,
      String? phone,
      String? address,
    }) => {
      'id': 'cc-1',
      'name': 'Acme GmbH',
      'taxiCompanyId': 'tc-1',
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
    };

    test('parses required fields', () {
      final cc = ClientCompany.fromJson(_json());
      expect(cc.id, 'cc-1');
      expect(cc.name, 'Acme GmbH');
      expect(cc.taxiCompanyId, 'tc-1');
    });

    test('optional fields are null when absent', () {
      final cc = ClientCompany.fromJson(_json());
      expect(cc.email, isNull);
      expect(cc.phone, isNull);
      expect(cc.address, isNull);
    });

    test('parses all optional fields when present', () {
      final cc = ClientCompany.fromJson(
        _json(
          email: 'acme@example.com',
          phone: '+4989123456',
          address: 'Hauptstraße 1, München',
        ),
      );
      expect(cc.email, 'acme@example.com');
      expect(cc.phone, '+4989123456');
      expect(cc.address, 'Hauptstraße 1, München');
    });
  });

  group('CreateClientCompanyRequest.toJson', () {
    test('includes required name field', () {
      final req = CreateClientCompanyRequest(name: 'Test GmbH');
      final json = req.toJson();
      expect(json['name'], 'Test GmbH');
    });

    test('omits null optional fields', () {
      final req = CreateClientCompanyRequest(name: 'Test GmbH');
      final json = req.toJson();
      expect(json.containsKey('email'), isFalse);
      expect(json.containsKey('phone'), isFalse);
      expect(json.containsKey('address'), isFalse);
    });

    test('includes optional fields when set', () {
      final req = CreateClientCompanyRequest(
        name: 'Test GmbH',
        email: 'test@test.com',
        phone: '+49123',
        address: 'Musterstraße 1',
      );
      final json = req.toJson();
      expect(json['email'], 'test@test.com');
      expect(json['phone'], '+49123');
      expect(json['address'], 'Musterstraße 1');
    });

    test('does not include id in toJson (server assigns it)', () {
      final req = CreateClientCompanyRequest(name: 'Test GmbH');
      final json = req.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('taxiCompanyId'), isFalse);
    });
  });
}
