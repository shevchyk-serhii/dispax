import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/saved_places/saved_places_bloc.dart';
import 'package:dispax/blocs/saved_places/saved_places_event.dart';
import 'package:dispax/blocs/saved_places/saved_places_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/client_address.dart';
import 'package:dispax/modules/ride_management/widgets/saved_place_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSavedPlacesBloc extends MockBloc<SavedPlacesEvent, SavedPlacesState>
    implements SavedPlacesBloc {}

class _FakeSavedPlacesEvent extends Fake implements SavedPlacesEvent {}

ClientAddress _home() => ClientAddress(
  id: 'addr-home',
  clientId: 'client-1',
  label: 'Home',
  address: 'Leopoldstr. 21',
  useCount: 1,
  createdAt: DateTime(2024, 1, 1),
  updatedAt: DateTime(2024, 1, 1),
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeSavedPlacesEvent()));

  late _MockSavedPlacesBloc bloc;
  late bool usePressed;

  setUp(() {
    bloc = _MockSavedPlacesBloc();
    usePressed = false;
    when(() => bloc.state).thenReturn(SavedPlacesState.loaded([_home()]));
    when(() => bloc.add(any())).thenAnswer((_) {});
  });

  // Pumps a button that opens the saved-place action menu for the Home place.
  Future<void> pumpMenuHost(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        home: BlocProvider<SavedPlacesBloc>.value(
          value: bloc,
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showSavedPlaceActions(
                  context,
                  place: _home(),
                  clientId: 'client-1',
                  onUse: () => usePressed = true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('menu shows Use / Edit / Remove for a filled slot', (
    tester,
  ) async {
    await pumpMenuHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Use this address'), findsOneWidget);
    expect(find.text('Edit address'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);
  });

  testWidgets('Use this address triggers onUse and dispatches nothing', (
    tester,
  ) async {
    await pumpMenuHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use this address'));
    await tester.pumpAndSettle();

    expect(usePressed, isTrue);
    verifyNever(() => bloc.add(any()));
  });

  testWidgets('Remove → confirm dispatches SavedPlacesDeleteRequested', (
    tester,
  ) async {
    await pumpMenuHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Tap "Remove" in the action sheet.
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    // Confirm in the dialog (second "Remove" — the destructive action button).
    expect(find.text('Remove this saved place?'), findsOneWidget);
    await tester.tap(find.text('Remove').last);
    await tester.pumpAndSettle();

    verify(
      () => bloc.add(
        const SavedPlacesDeleteRequested(
          clientId: 'client-1',
          addressId: 'addr-home',
        ),
      ),
    ).called(1);
  });

  testWidgets('Remove → cancel dispatches nothing', (tester) async {
    await pumpMenuHost(tester);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    verifyNever(() => bloc.add(any()));
  });
}
