import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/modules/ride_management/models/external_driver.dart';
import 'package:dispax/modules/ride_management/models/partner_company.dart';
import 'package:dispax/widgets/common/hand_off_ride_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  late MockRideService rideService;

  setUp(() {
    rideService = MockRideService();
    // Empty directories — the form loads and the dropdowns are empty, which is
    // exactly the state in which a dispatcher taps "+ Add new company".
    when(
      () => rideService.listPartnerCompanies(),
    ).thenAnswer((_) async => <PartnerCompany>[]);
    when(
      () => rideService.listExternalDrivers(),
    ).thenAnswer((_) async => <ExternalDriver>[]);
  });

  // Pumps the dialog under the given theme brightness, then opens the inline
  // "add company" form so its Container is in the tree.
  Future<void> pumpAndOpenInlineForm(
    WidgetTester tester, {
    required Brightness brightness,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: HandOffRideDialog(rideId: 'ride-1', rideService: rideService),
        ),
      ),
    );
    // Let _load() resolve.
    await tester.pumpAndSettle();

    await tester.tap(find.text('+ Add new company'));
    await tester.pumpAndSettle();
  }

  Container inlineForm(WidgetTester tester) =>
      tester.widget<Container>(find.byKey(const Key('handOffInlineForm')));

  group('HandOffRideDialog inline add form follows the theme', () {
    testWidgets('uses the light tint in light mode', (tester) async {
      await pumpAndOpenInlineForm(tester, brightness: Brightness.light);

      final decoration = inlineForm(tester).decoration as BoxDecoration;
      expect(decoration.color, AppColors.rideHandedOffBg);
    });

    testWidgets('uses the deep dark surface in dark mode', (tester) async {
      await pumpAndOpenInlineForm(tester, brightness: Brightness.dark);

      final decoration = inlineForm(tester).decoration as BoxDecoration;
      expect(decoration.color, AppColors.rideHandedOffBgDark);
    });
  });
}
