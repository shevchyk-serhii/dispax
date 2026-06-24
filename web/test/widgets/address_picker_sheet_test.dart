import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/client_address.dart';
import 'package:dispax/modules/ride_management/widgets/address_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ClientAddress _addr(String label, String address) => ClientAddress(
  id: 'addr-$label',
  clientId: 'client-1',
  label: label,
  address: address,
  useCount: 1,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

void main() {
  // Pumps a host button that opens the picker with [savedAddresses] and stores
  // the popped result.
  Future<String?> openPicker(
    WidgetTester tester, {
    required List<ClientAddress> savedAddresses,
  }) async {
    String? popped;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await showAddressPickerSheet(
                  context,
                  isFrom: false,
                  current: '',
                  savedPlaces: const [],
                  savedAddresses: savedAddresses,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return popped;
  }

  testWidgets('renders labelled saved addresses (label + address)', (
    tester,
  ) async {
    await openPicker(
      tester,
      savedAddresses: [
        _addr('Home', 'Leopoldstr. 21'),
        _addr('Office', 'Maximilianstr. 5'),
      ],
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Leopoldstr. 21'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Maximilianstr. 5'), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    expect(find.byIcon(Icons.business_outlined), findsOneWidget);
  });

  testWidgets('tapping a labelled tile pops its address (not its label)', (
    tester,
  ) async {
    // We can't read `popped` after pumpAndSettle in the same call easily, so
    // re-open and tap inside one flow.
    String? popped;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () async {
                popped = await showAddressPickerSheet(
                  context,
                  isFrom: false,
                  current: '',
                  savedPlaces: const [],
                  savedAddresses: [_addr('Home', 'Leopoldstr. 21')],
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();

    expect(popped, 'Leopoldstr. 21');
  });
}
