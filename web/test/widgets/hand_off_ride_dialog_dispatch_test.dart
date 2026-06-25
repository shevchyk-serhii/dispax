// Tests the dialog -> RideBloc seam for the dispatcher hand-off.
//
// The dialog is shown via showAdaptiveDialog, so it is mounted in the navigator
// overlay — which does NOT inherit the dashboard's BlocProvider. The old code
// called `context.read<RideBloc>()` from inside the dialog, which threw
// ProviderNotFoundException there: tapping "Hand Off" appeared to do nothing.
//
// The fix has the dialog return the dispatcher's HandOffSelection via the
// navigator pop value; the caller (which owns the bloc) dispatches the event.
// These tests reproduce the real tree (RideBloc provided ABOVE the widget that
// opens the dialog) and assert the event reaches the bloc with the selected
// ids — and that cancelling dispatches nothing.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/modules/ride_management/models/external_driver.dart';
import 'package:dispax/modules/ride_management/models/partner_company.dart';
import 'package:dispax/widgets/common/hand_off_ride_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  late MockRideService rideService;
  late MockRideBloc rideBloc;

  final company = PartnerCompany(
    id: 'partner-1',
    name: 'Acme Cabs',
    taxiCompanyId: 'company-1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final driver = ExternalDriver(
    id: 'ext-driver-1',
    name: 'Hans Müller',
    taxiCompanyId: 'company-1',
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  setUpAll(() {
    registerFallbackValue(
      const RideHandOffRequested(
        rideId: 'x',
        externalDriverId: 'x',
        partnerCompanyId: 'x',
      ),
    );
  });

  setUp(() {
    rideService = MockRideService();
    rideBloc = MockRideBloc();
    // BlocProvider subscribes to the bloc's stream/state on build; give the
    // mock a real (empty) stream so the provider mounts cleanly.
    whenListen(
      rideBloc,
      const Stream<RideState>.empty(),
      initialState: const RideState(),
    );
    when(() => rideBloc.add(any())).thenReturn(null);
    when(
      () => rideService.listPartnerCompanies(),
    ).thenAnswer((_) async => [company]);
    when(
      () => rideService.listExternalDrivers(),
    ).thenAnswer((_) async => [driver]);
  });

  // Pumps a host screen with RideBloc provided above it, then opens the dialog
  // via showAdaptiveDialog — exactly how PendingRidesPanel does it, so the
  // dialog lands in the overlay without RideBloc in its own subtree.
  Future<void> pumpAndOpenDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<RideBloc>.value(
          value: rideBloc,
          child: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () {
                    showAdaptiveDialog<HandOffSelection>(
                      context: context,
                      builder: (_) => HandOffRideDialog(
                        rideId: 'ride-1',
                        rideService: rideService,
                      ),
                    ).then((selection) {
                      if (selection == null) return;
                      context.read<RideBloc>().add(
                        RideHandOffRequested(
                          rideId: 'ride-1',
                          externalDriverId: selection.externalDriverId,
                          partnerCompanyId: selection.partnerCompanyId,
                        ),
                      );
                    });
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> selectCompanyAndDriver(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButton<PartnerCompany>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Acme Cabs').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButton<ExternalDriver>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hans Müller').last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'tapping "Hand Off" dispatches RideHandOffRequested to the bloc',
    (tester) async {
      await pumpAndOpenDialog(tester);
      await selectCompanyAndDriver(tester);

      await tester.tap(find.text('Hand Off'));
      await tester.pumpAndSettle();

      verify(
        () => rideBloc.add(
          const RideHandOffRequested(
            rideId: 'ride-1',
            externalDriverId: 'ext-driver-1',
            partnerCompanyId: 'partner-1',
          ),
        ),
      ).called(1);
    },
  );

  testWidgets('cancelling the dialog dispatches nothing', (tester) async {
    await pumpAndOpenDialog(tester);
    await selectCompanyAndDriver(tester);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => rideBloc.add(any()));
  });
}
