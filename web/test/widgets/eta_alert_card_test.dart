import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/dashboard/dispatcher/widgets/eta_alert_card.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

void main() {
  const info = EtaAtRiskInfo(
    rideId: 'ride-1',
    driverName: 'Hans Müller',
    etaMinutes: 12,
    pickupInMinutes: 7,
    slackMinutes: -5,
  );

  group('EtaAlertCard', () {
    testWidgets('renders slack minutes correctly', (tester) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: info)));
      expect(find.textContaining('Slack -5min'), findsOneWidget);
    });

    testWidgets('renders driver name', (tester) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: info)));
      expect(find.text('Hans Müller'), findsOneWidget);
    });

    testWidgets('onDismiss fires when X button is tapped', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        _wrap(EtaAlertCard(info: info, onDismiss: () => dismissed = true)),
      );
      // The X button is the IconButton child
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('onReassign fires when Reassign button is tapped', (
      tester,
    ) async {
      bool reassigned = false;
      await tester.pumpWidget(
        _wrap(EtaAlertCard(info: info, onReassign: () => reassigned = true)),
      );
      await tester.tap(find.text('Reassign'));
      await tester.pump();
      expect(reassigned, isTrue);
    });

    testWidgets('shows alert icon (Icon widget present)', (tester) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: info)));
      // EtaAlertCard always shows an Icon widget for the warning
      expect(find.byType(Icon), findsWidgets);
    });

    testWidgets('renders in dark mode without errors', (tester) async {
      await tester.pumpWidget(
        _wrap(
          EtaAlertCard(info: info, onDismiss: () {}),
          brightness: Brightness.dark,
        ),
      );
      expect(find.byType(EtaAlertCard), findsOneWidget);
    });
  });
}
