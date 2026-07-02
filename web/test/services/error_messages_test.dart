// Unit tests for the centralized error-UX layer introduced in the
// error-ux-foundation phase:
//   - ApiException.kind correctly classifies failures by status code / cause
//   - friendlyError(error, l10n) returns a short localized message and NEVER
//     leaks the backend URL, the exception class name, an HTTP status code, or
//     a stack-trace tail to the user.
//
// Pure-Dart: loads AppLocalizations via the delegate (no widget pump needed).

import 'dart:async';
import 'dart:io';

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/services/error_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppLocalizations> _l10n([String code = 'en']) =>
    AppLocalizations.delegate.load(Locale(code));

// The raw, leak-prone message that actually reached the dispatcher's screen.
const _leakyTimeoutMessage =
    'Failed to perform GET request to '
    'https://dispax-o2trzxjbva-ew.a.run.app/api/rides/pending: '
    'TimeoutException after 0:00:15.000000: Future not completed';

void main() {
  group('ApiException.kind', () {
    test('401 -> unauthorized', () {
      expect(
        ApiException('x', statusCode: 401).kind,
        AppErrorKind.unauthorized,
      );
    });
    test('404 -> notFound', () {
      expect(ApiException('x', statusCode: 404).kind, AppErrorKind.notFound);
    });
    test('409 -> conflict', () {
      expect(ApiException('x', statusCode: 409).kind, AppErrorKind.conflict);
    });
    test('400 -> validation', () {
      expect(ApiException('x', statusCode: 400).kind, AppErrorKind.validation);
    });
    test('422 -> validation', () {
      expect(ApiException('x', statusCode: 422).kind, AppErrorKind.validation);
    });
    test('500 -> server', () {
      expect(ApiException('x', statusCode: 500).kind, AppErrorKind.server);
    });
    test('503 -> server', () {
      expect(ApiException('x', statusCode: 503).kind, AppErrorKind.server);
    });
    test('TimeoutException cause -> timeout', () {
      final e = ApiException('x', cause: TimeoutException('t'));
      expect(e.kind, AppErrorKind.timeout);
    });
    test('SocketException cause -> network', () {
      final e = ApiException('x', cause: const SocketException('s'));
      expect(e.kind, AppErrorKind.network);
    });
    test('falls back to message text when no cause/status (timeout)', () {
      expect(ApiException(_leakyTimeoutMessage).kind, AppErrorKind.timeout);
    });
    test('unknown when nothing classifies it', () {
      expect(ApiException('something odd').kind, AppErrorKind.unknown);
    });
    test('UnauthorizedException is always unauthorized', () {
      expect(UnauthorizedException().kind, AppErrorKind.unauthorized);
    });
  });

  // Release-mode behaviour: includeDebugDetail:false mirrors a production build.
  group('friendlyError — never leaks internals (release output)', () {
    test('timeout (the reported bug) -> clean timeout message', () async {
      final l10n = await _l10n();
      final msg = friendlyError(
        ApiException(_leakyTimeoutMessage, cause: TimeoutException('t')),
        l10n,
        includeDebugDetail: false,
      );
      expect(msg, l10n.errorTimeout);
      expect(msg, isNot(contains('http')));
      expect(msg, isNot(contains('ApiException')));
      expect(msg, isNot(contains('TimeoutException')));
      expect(msg, isNot(contains('/api/')));
      expect(msg, isNot(contains('0:00:15')));
    });

    test('network -> clean network message', () async {
      final l10n = await _l10n();
      final msg = friendlyError(
        ApiException('boom', cause: const SocketException('s')),
        l10n,
        includeDebugDetail: false,
      );
      expect(msg, l10n.errorNetwork);
    });

    test('500 -> server message (no status code shown)', () async {
      final l10n = await _l10n();
      final msg = friendlyError(
        ApiException('x', statusCode: 500),
        l10n,
        includeDebugDetail: false,
      );
      expect(msg, l10n.errorServer);
      expect(msg, isNot(contains('500')));
    });

    test('401 / UnauthorizedException -> session expired', () async {
      final l10n = await _l10n();
      expect(
        friendlyError(UnauthorizedException(), l10n, includeDebugDetail: false),
        l10n.errorSessionExpired,
      );
      expect(
        friendlyError(
          ApiException('x', statusCode: 401),
          l10n,
          includeDebugDetail: false,
        ),
        l10n.errorSessionExpired,
      );
    });

    test(
      'validation surfaces the backend reason, stripped of the action prefix',
      () async {
        final l10n = await _l10n();
        final e = ApiException(
          'Failed to create ride: Pickup location cannot be empty',
          statusCode: 400,
        );
        expect(
          friendlyError(e, l10n, includeDebugDetail: false),
          'Pickup location cannot be empty',
        );
      },
    );

    test(
      'validation with a technical-looking detail falls back to generic',
      () async {
        final l10n = await _l10n();
        final e = ApiException(
          'Failed to create ride: ApiException: https://x/api/rides',
          statusCode: 400,
        );
        expect(
          friendlyError(e, l10n, includeDebugDetail: false),
          l10n.errorGeneric,
        );
      },
    );

    test('a non-ApiException error -> generic, no toString leak', () async {
      final l10n = await _l10n();
      final msg = friendlyError(
        StateError('internal detail xyz'),
        l10n,
        includeDebugDetail: false,
      );
      expect(msg, l10n.errorGeneric);
      expect(msg, isNot(contains('xyz')));
    });

    test('localizes per locale (de/uk)', () async {
      final de = await _l10n('de');
      final uk = await _l10n('uk');
      final e = ApiException('x', cause: TimeoutException('t'));
      expect(friendlyError(e, de, includeDebugDetail: false), de.errorTimeout);
      expect(friendlyError(e, uk, includeDebugDetail: false), uk.errorTimeout);
      expect(de.errorTimeout, isNot(equals(uk.errorTimeout)));
    });
  });

  group('friendlyError — debug detail', () {
    test('appends the technical cause only when debug detail is on', () async {
      final l10n = await _l10n();
      final e = ApiException(
        _leakyTimeoutMessage,
        cause: TimeoutException('t'),
      );
      final debug = friendlyError(e, l10n, includeDebugDetail: true);
      expect(debug, startsWith(l10n.errorTimeout));
      expect(debug, contains('[debug]'));
      expect(debug, contains('TimeoutException'));
    });
  });
}
