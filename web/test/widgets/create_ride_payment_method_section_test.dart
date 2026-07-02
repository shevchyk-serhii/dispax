import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/payment_method.dart';
import 'package:dispax/modules/ride_management/widgets/sections/create_ride_payment_method_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late CreateRideFormBloc formBloc;

  setUp(() => formBloc = CreateRideFormBloc());
  tearDown(() => formBloc.close());

  Future<void> pumpSection(
    WidgetTester tester, {
    Locale locale = const Locale('en'),
    PaymentMethod selected = PaymentMethod.invoice,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        home: Scaffold(
          body: BlocProvider<CreateRideFormBloc>.value(
            value: formBloc,
            child: CreateRidePaymentMethodSection(
              selectedPaymentMethod: selected,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the German labels for all four methods', (tester) async {
    await pumpSection(tester, locale: const Locale('de'));

    // The dropdown shows the selected value (Rechnung); open it to see the rest.
    expect(find.text('Rechnung'), findsWidgets);

    await tester.tap(find.byType(CreateRidePaymentMethodSection));
    await tester.pumpAndSettle();

    expect(find.text('Kreditkarte'), findsWidgets);
    expect(find.text('Bar'), findsWidgets);
    expect(find.text('Zahlung'), findsWidgets);
  });

  testWidgets('selecting a method dispatches PaymentMethodSelected', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.tap(find.byType(CreateRidePaymentMethodSection));
    await tester.pumpAndSettle();

    // Tap "Cash" in the opened menu (last match is the menu item).
    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();

    expect(formBloc.state.selectedPaymentMethod, PaymentMethod.cash);
  });
}
