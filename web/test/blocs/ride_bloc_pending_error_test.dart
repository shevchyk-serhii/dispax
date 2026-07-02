// Phase 2 (error-UX): the dispatcher's pending-rides load failure must carry a
// TYPED cause in RideState so the UI can render a localized, non-technical
// message (the reported bug was a raw timeout banner). This locks in:
//   - onLoadPendingRequested puts the caught exception into RideState.error
//   - that exception still classifies as a timeout (Phase 1 rethrow preserved
//     the cause), so friendlyError returns the clean timeout text — NOT generic.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/services/error_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

// The exact wrapped timeout that reached the dispatcher screen, as the ApiClient
// now produces it (message wraps the URL, but the typed cause is preserved).
ApiException _pendingTimeout() => ApiException(
  'Failed to perform GET request to '
  'https://dispax-o2trzxjbva-ew.a.run.app/api/rides/pending: '
  'TimeoutException after 0:00:15.000000: Future not completed',
  cause: TimeoutException('t'),
);

void main() {
  late MockRideService mockRideService;

  setUp(() {
    mockRideService = MockRideService();
    when(() => mockRideService.dispose()).thenReturn(null);
  });

  RideBloc buildBloc() => RideBloc(rideService: mockRideService);

  group('RideBloc — pending load error carries a typed cause', () {
    blocTest<RideBloc, RideState>(
      'onLoadPendingRequested stores the exception in state.error (timeout kind)',
      build: () {
        when(
          () => mockRideService.getPendingRides(),
        ).thenThrow(_pendingTimeout());
        return buildBloc();
      },
      act: (bloc) => bloc.add(const RideLoadPendingRequested()),
      expect: () => [
        isA<RideState>().having((s) => s.isLoading, 'isLoading', true),
        isA<RideState>()
            .having((s) => s.hasError, 'hasError', true)
            .having((s) => s.error, 'error', isA<ApiException>())
            .having(
              (s) => (s.error as ApiException).kind,
              'kind',
              AppErrorKind.timeout,
            ),
      ],
    );

    test(
      'the stored error maps to the clean timeout message (not generic)',
      () async {
        when(
          () => mockRideService.getPendingRides(),
        ).thenThrow(_pendingTimeout());
        final bloc = buildBloc();
        bloc.add(const RideLoadPendingRequested());
        await bloc.stream.firstWhere((s) => s.hasError);

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        final msg = friendlyError(
          bloc.state.error,
          l10n,
          includeDebugDetail: false,
        );

        expect(msg, l10n.errorTimeout);
        expect(msg, isNot(l10n.errorGeneric));
        expect(msg, isNot(contains('http')));
        expect(msg, isNot(contains('TimeoutException')));
        await bloc.close();
      },
    );
  });
}
