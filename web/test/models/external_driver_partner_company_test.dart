// fromJson hardening: required createdAt/updatedAt go through JsonParse so a
// missing/malformed timestamp throws a FormatException naming the field
// instead of an opaque TypeError from DateTime.parse(null).

import 'package:dispax/modules/ride_management/models/external_driver.dart';
import 'package:dispax/modules/ride_management/models/partner_company.dart';
import 'package:flutter_test/flutter_test.dart';

Matcher _formatExceptionNaming(String field) => throwsA(
  isA<FormatException>().having((e) => e.message, 'message', contains(field)),
);

void main() {
  group('ExternalDriver.fromJson', () {
    Map<String, dynamic> json0() => {
      'id': 'ed-1',
      'name': 'Partner Driver',
      'taxiCompanyId': 'tc-1',
      'createdAt': '2026-06-01T10:00:00Z',
      'updatedAt': '2026-06-02T10:00:00Z',
    };

    test('parses required fields', () {
      final driver = ExternalDriver.fromJson(json0());
      expect(driver.id, 'ed-1');
      expect(driver.createdAt, DateTime.parse('2026-06-01T10:00:00Z'));
      expect(driver.updatedAt, DateTime.parse('2026-06-02T10:00:00Z'));
    });

    for (final field in ['createdAt', 'updatedAt']) {
      test('missing $field throws a FormatException naming it', () {
        expect(
          () => ExternalDriver.fromJson(json0()..remove(field)),
          _formatExceptionNaming(field),
        );
      });
    }
  });

  group('PartnerCompany.fromJson', () {
    Map<String, dynamic> json0() => {
      'id': 'pc-1',
      'name': 'Partner GmbH',
      'taxiCompanyId': 'tc-1',
      'createdAt': '2026-06-01T10:00:00Z',
      'updatedAt': '2026-06-02T10:00:00Z',
    };

    test('parses required fields', () {
      final company = PartnerCompany.fromJson(json0());
      expect(company.id, 'pc-1');
      expect(company.createdAt, DateTime.parse('2026-06-01T10:00:00Z'));
      expect(company.updatedAt, DateTime.parse('2026-06-02T10:00:00Z'));
    });

    for (final field in ['createdAt', 'updatedAt']) {
      test('missing $field throws a FormatException naming it', () {
        expect(
          () => PartnerCompany.fromJson(json0()..remove(field)),
          _formatExceptionNaming(field),
        );
      });
    }
  });
}
