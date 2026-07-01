// Widget tests for CreateRidePriceSection — the optional manual price field of
// the create-ride form.
//
// The field is a bare TextField (not a FormField): it filters input to digits +
// separators, normalises a decimal comma to a dot, and forwards the parsed value
// as RidePriceChanged(double?) to CreateRideFormBloc. These tests pin the
// edge-case input handling (comma, clear, letters filtered, minus filtered, zero
// forwarded) and the external clear-sync via didUpdateWidget.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/widgets/sections/create_ride_price_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeFormEvent extends Fake implements CreateRideFormEvent {}

class _MockFormBloc extends MockBloc<CreateRideFormEvent, CreateRideFormState>
    implements CreateRideFormBloc {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeFormEvent()));

  late _MockFormBloc bloc;

  setUp(() {
    bloc = _MockFormBloc();
    when(() => bloc.state).thenReturn(CreateRideFormState.initial());
  });

  Widget buildSubject({double? price}) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<CreateRideFormBloc>.value(
        value: bloc,
        child: CreateRidePriceSection(price: price),
      ),
    ),
  );

  List<double?> capturedPrices() => verify(() => bloc.add(captureAny()))
      .captured
      .whereType<RidePriceChanged>()
      .map((e) => e.price)
      .toList();

  testWidgets('a plain number forwards the parsed double', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.enterText(find.byType(TextField), '45');
    expect(capturedPrices().last, 45.0);
  });

  testWidgets('a decimal comma is normalised to a dot', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.enterText(find.byType(TextField), '45,5');
    expect(capturedPrices().last, 45.5);
  });

  testWidgets('clearing a typed value forwards null', (tester) async {
    await tester.pumpWidget(buildSubject());
    // Type a value first, then clear it — clearing an already-empty field
    // wouldn't fire onChanged (no text change), so seed it.
    await tester.enterText(find.byType(TextField), '45');
    await tester.enterText(find.byType(TextField), '');
    expect(capturedPrices().last, isNull);
  });

  testWidgets('letters are filtered out by the input formatter', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.enterText(find.byType(TextField), '12a3');
    expect(find.text('123'), findsOneWidget); // 'a' stripped
    expect(capturedPrices().last, 123.0);
  });

  testWidgets('a minus sign is filtered out (no negative prices)', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.enterText(find.byType(TextField), '-5');
    expect(find.text('5'), findsOneWidget); // '-' stripped
    expect(capturedPrices().last, 5.0);
  });

  testWidgets('zero is forwarded (backend rejects it, not the field)', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.enterText(find.byType(TextField), '0');
    expect(capturedPrices().last, 0.0);
  });

  testWidgets('external price clear syncs the controller', (tester) async {
    await tester.pumpWidget(buildSubject(price: 45.0));
    expect(find.text('45'), findsOneWidget);

    // Simulate Clear Form: the parent rebuilds the section with a null price.
    await tester.pumpWidget(buildSubject(price: null));
    expect(find.text('45'), findsNothing);
  });
}
