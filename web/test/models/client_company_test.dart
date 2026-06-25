import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/billing/models/client_company.dart';

void main() {
  group('ClientCompany.fromJson', () {
    Map<String, dynamic> json0({
      String? email,
      String? phone,
      String? address,
      String? preferredLanguage,
    }) => {
      'id': 'cc-1',
      'name': 'Acme GmbH',
      'taxiCompanyId': 'tc-1',
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
      if (address != null) 'address': address,
      if (preferredLanguage != null) 'preferredLanguage': preferredLanguage,
    };

    test('parses required fields', () {
      final cc = ClientCompany.fromJson(json0());
      expect(cc.id, 'cc-1');
      expect(cc.name, 'Acme GmbH');
      expect(cc.taxiCompanyId, 'tc-1');
    });

    test('throws a FormatException naming a missing required field', () {
      final json = json0()..remove('taxiCompanyId');
      expect(
        () => ClientCompany.fromJson(json),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('taxiCompanyId'),
          ),
        ),
      );
    });

    test('optional fields are null when absent', () {
      final cc = ClientCompany.fromJson(json0());
      expect(cc.email, isNull);
      expect(cc.phone, isNull);
      expect(cc.address, isNull);
      expect(cc.preferredLanguage, isNull);
    });

    test('parses all optional fields when present', () {
      final cc = ClientCompany.fromJson(
        json0(
          email: 'acme@example.com',
          phone: '+4989123456',
          address: 'Hauptstraße 1, München',
          preferredLanguage: 'en',
        ),
      );
      expect(cc.email, 'acme@example.com');
      expect(cc.phone, '+4989123456');
      expect(cc.address, 'Hauptstraße 1, München');
      expect(cc.preferredLanguage, 'en');
    });

    test('parses preferredLanguage when set to uk', () {
      final cc = ClientCompany.fromJson(json0(preferredLanguage: 'uk'));
      expect(cc.preferredLanguage, 'uk');
    });

    // Regression: vatId (USt-IdNr.) must round-trip so invoices to companies
    // carry the recipient's VAT number.
    test('parses and re-serializes vatId', () {
      final cc = ClientCompany.fromJson({
        'id': 'cc-1',
        'name': 'Acme GmbH',
        'taxiCompanyId': 'tc-1',
        'vatId': 'DE123456789',
      });
      expect(cc.vatId, 'DE123456789');
      expect(cc.toJson()['vatId'], 'DE123456789');
    });

    test('vatId is null when absent', () {
      final cc = ClientCompany.fromJson(json0());
      expect(cc.vatId, isNull);
      expect(cc.toJson().containsKey('vatId'), isFalse);
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
      expect(json.containsKey('preferredLanguage'), isFalse);
    });

    test('includes optional fields when set', () {
      final req = CreateClientCompanyRequest(
        name: 'Test GmbH',
        email: 'test@test.com',
        phone: '+49123',
        address: 'Musterstraße 1',
        preferredLanguage: 'uk',
      );
      final json = req.toJson();
      expect(json['email'], 'test@test.com');
      expect(json['phone'], '+49123');
      expect(json['address'], 'Musterstraße 1');
      expect(json['preferredLanguage'], 'uk');
    });

    test('does not include id in toJson (server assigns it)', () {
      final req = CreateClientCompanyRequest(name: 'Test GmbH');
      final json = req.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('taxiCompanyId'), isFalse);
    });

    test('preferredLanguage null is omitted from toJson', () {
      final req = CreateClientCompanyRequest(
        name: 'Test GmbH',
        preferredLanguage: null,
      );
      final json = req.toJson();
      expect(json.containsKey('preferredLanguage'), isFalse);
    });

    test('preferredLanguage de is included in toJson', () {
      final req = CreateClientCompanyRequest(
        name: 'Test GmbH',
        preferredLanguage: 'de',
      );
      final json = req.toJson();
      expect(json['preferredLanguage'], 'de');
    });

    test('vatId is included when set and omitted when null', () {
      expect(
        CreateClientCompanyRequest(
          name: 'Test GmbH',
          vatId: 'DE999',
        ).toJson()['vatId'],
        'DE999',
      );
      expect(
        CreateClientCompanyRequest(
          name: 'Test GmbH',
        ).toJson().containsKey('vatId'),
        isFalse,
      );
    });
  });
}
