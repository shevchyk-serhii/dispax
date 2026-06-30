// Phase 4 guard: keep raw exceptions out of user-facing strings.
//
// The error-UX refactor replaced `l10n.genericError(e.toString())` and bare
// `e.toString()` in SnackBars/Text with the central `friendlyError(e, l10n)`
// mapper. This static test scans lib/ and fails if those anti-patterns reappear,
// so the cleanup can't silently regress.
//
// KNOWN_REMAINING lists the few files not yet migrated (tracked as the tail of
// Phase 4). They are allow-listed so this test is green today and turns red on
// any NEW violation. Shrink this list as the tail is finished — never grow it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // Files with a still-pending raw-leak site (Phase 4 tail). Do not add to this.
  const knownRemaining = <String>{
    'lib/screens/geofence_screen.dart',
    'lib/screens/gdpr_screen.dart',
    'lib/screens/settings_screen.dart',
  };

  // The l10n generated file legitimately defines the `genericError` key.
  bool isExempt(String path) =>
      path.endsWith('app_localizations.dart') ||
      path.contains('/l10n/') ||
      // The mapper itself is allowed to reference the raw exception.
      path.endsWith('modules/core/services/error_messages.dart') ||
      knownRemaining.any(path.endsWith);

  test('no genericError(e.toString()) / raw e.toString() in user-facing UI', () {
    final libDir = Directory('lib');
    final offenders = <String>[];

    final genericError = RegExp(r'\.genericError\(');
    // e.toString() interpolated into a Text(...) or SnackBar content / _error.
    final rawInText = RegExp(
      r"(Text\(|content:\s*Text\(|_error\s*=\s*)[^\n;]*\be\.toString\(\)",
    );

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (isExempt(entity.path)) continue;
      final src = entity.readAsStringSync();
      for (final (i, line) in src.split('\n').indexed) {
        if (genericError.hasMatch(line) || rawInText.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: ${line.trim()}');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Raw exception leaked to UI. Use friendlyError(e, l10n) instead:\n'
          '${offenders.join('\n')}',
    );
  });
}
