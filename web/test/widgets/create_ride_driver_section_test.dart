import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/ride_management/widgets/sections/create_ride_driver_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// The driver create-ride form replaced the full driver dropdown (which
// pre-selected the driver as self) with an opt-in "Assign to me" switch that
// defaults to OFF. OFF → the ride has no driver and goes to the dispatcher pool;
// ON → the request carries the driver's own id (self-assign).

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _driver() => Person(
  id: 'driver-self-1',
  name: 'Hans Weber',
  email: 'hans@example.com',
  role: PersonRole.driver,
  companyId: 'company-1',
  phone: '+491111111111',
);

void main() {
  late _MockAuthBloc authBloc;
  late CreateRideFormBloc formBloc;

  setUp(() {
    authBloc = _MockAuthBloc();
    formBloc = CreateRideFormBloc();
    when(() => authBloc.apiClient).thenReturn(_MockApiClient());
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_driver()));
  });

  tearDown(() => formBloc.close());

  Future<void> pumpSection(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<CreateRideFormBloc>.value(value: formBloc),
            ],
            child: const CreateRideDriverSection(),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('defaults to OFF — no driver pre-selected (ride goes to pool)', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('Assign to me'), findsOneWidget);
    expect(formBloc.state.selectedDriverId, isNull);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets('turning it ON self-assigns (driverId = current driver)', (
    tester,
  ) async {
    await pumpSection(tester);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(formBloc.state.selectedDriverId, _driver().id);
  });

  testWidgets('when already ON, the switch renders ON and a tap clears it '
      '(back to pool)', (tester) async {
    // Seed the form so the driver is already self-assigned, then render: the
    // switch must reflect ON and a single tap must send DriverSelected(null).
    formBloc.add(DriverSelected(_driver().id));
    await tester.pump();

    await pumpSection(tester);

    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
      reason: 'switch reflects the already-self-assigned state',
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(formBloc.state.selectedDriverId, isNull);
  });
}
