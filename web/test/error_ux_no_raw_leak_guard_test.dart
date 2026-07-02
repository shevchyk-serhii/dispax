// Phase 4 guard: keep raw exceptions out of user-facing strings.
//
// The error-UX refactor replaced `l10n.genericError(e.toString())` and bare
// `e.toString()` in SnackBars/Text with the central `friendlyError(e, l10n)`
// mapper. This static test scans lib/ and fails if those anti-patterns reappear,
// so the cleanup can't silently regress.
//
// The whole user-facing tree is migrated: every raw-exception / status-code leak
// now goes through friendlyError. This test fails if any of those anti-patterns
// reappears, so the cleanup can't silently regress.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // The l10n generated file legitimately defines the `genericError` key.
  bool isExempt(String path) =>
      path.endsWith('app_localizations.dart') ||
      path.contains('/l10n/') ||
      // The mapper itself is allowed to reference the raw exception.
      path.endsWith('modules/core/services/error_messages.dart');

  test('no raw exception / status code leaks in user-facing UI', () {
    final libDir = Directory('lib');
    final offenders = <String>[];

    final genericError = RegExp(r'\.genericError\(');
    // e.toString() interpolated into a Text(...) or SnackBar content / _error.
    final rawInText = RegExp(
      r"(Text\(|content:\s*Text\(|_error\s*=\s*)[^\n;]*\be\.toString\(\)",
    );
    // A raw exception interpolated into a string SHOWN to the user, i.e. on a
    // line that also builds a Text(...) / SnackBar content. A bare `'…: $e'` in
    // a bloc's internal errorMessage fallback or a debugPrint is fine (the UI
    // renders the typed cause via friendlyError, never errorMessage), so it is
    // deliberately NOT flagged.
    final rawDollarEInText = RegExp(r"(Text\(|content:)[^\n]*'[^'\n]*:\s*\$e'");
    // An HTTP status code shown to the user (response.statusCode in a string),
    // except inside an ApiException(...) constructor — that's the sanctioned
    // path (friendlyError turns the code into a neutral message).
    final statusInText = RegExp(r'\$\{?(?:response|resp)\.statusCode\}?');

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (isExempt(entity.path)) continue;
      final src = entity.readAsStringSync();
      for (final (i, line) in src.split('\n').indexed) {
        final trimmed = line.trim();
        if (genericError.hasMatch(line) ||
            rawInText.hasMatch(line) ||
            rawDollarEInText.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: $trimmed');
        }
        // A status code interpolated into a string the USER sees — a Text(...),
        // a SnackBar content, or an `_error =` assignment. Services that bake
        // the code into an ApiException.message / a throw / a debugPrint are
        // fine: friendlyError sanitizes the message and logs aren't UI.
        final isUiLine = RegExp(r'Text\(|content:|_error\s*=').hasMatch(line);
        if (isUiLine && statusInText.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: $trimmed');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Raw exception / HTTP status leaked to UI. Wrap it: '
          'friendlyError(e, l10n) or '
          'friendlyError(ApiException(msg, statusCode: ...), l10n):\n'
          '${offenders.join('\n')}',
    );
  });
}
