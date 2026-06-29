import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/core/api_contract.dart';
import 'package:dispax/modules/core/services/version_service.dart';

void main() {
  group('isClientOutdated', () {
    test('true when the client contract is below the backend minimum', () {
      expect(isClientOutdated(1, 2), isTrue);
    });

    test('false when the client meets the minimum', () {
      expect(isClientOutdated(2, 2), isFalse);
    });

    test('false when the client is ahead of the minimum', () {
      expect(isClientOutdated(3, 2), isFalse);
    });
  });

  group('BackendVersion.fromJson', () {
    test('parses apiVersion and minClientVersion', () {
      final v = BackendVersion.fromJson(
        jsonDecode(
              '{"version":"0.1.0","commit":"a1b2c3d","branch":"master",'
              '"buildTime":"2026-06-29T06:23:24Z","apiVersion":3,"minClientVersion":2}',
            )
            as Map<String, dynamic>,
      );
      expect(v.apiVersion, 3);
      expect(v.minClientVersion, 2);
    });

    test('defaults the contract fields to 0 when absent (old backend)', () {
      final v = BackendVersion.fromJson(
        jsonDecode('{"version":"0.1.0","commit":"","branch":"","buildTime":""}')
            as Map<String, dynamic>,
      );
      expect(v.apiVersion, 0);
      expect(v.minClientVersion, 0);
    });
  });
}
