import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/widgets/ride_info_row.dart';

void main() {
  Widget mount(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('shows a copy icon when copyable is true', (tester) async {
    await tester.pumpWidget(
      mount(
        const RideInfoRow(
          icon: Icons.location_on,
          label: 'Pickup',
          text: 'Munich Airport',
          copyable: true,
        ),
      ),
    );
    expect(find.byIcon(Icons.copy), findsOneWidget);
  });

  testWidgets('shows no copy icon by default (copyable false)', (tester) async {
    await tester.pumpWidget(
      mount(
        const RideInfoRow(
          icon: Icons.access_time,
          label: 'Pickup time',
          text: '10:00',
        ),
      ),
    );
    expect(find.byIcon(Icons.copy), findsNothing);
  });
}
