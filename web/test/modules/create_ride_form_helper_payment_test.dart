// Verifies that CreateRideFormHelper.handleFormSubmission carries the form's
// selectedPaymentMethod all the way into the CreateRideRequest handed to the
// RideBloc / RideService. Without this, the dropdown selection would be silently
// dropped at submission time (the dropdown updates state, but submission must
// forward it).

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/ride_management/helpers/create_ride_form_helper.dart';
import 'package:dispax/modules/ride_management/models/create_ride_request.dart';
import 'package:dispax/modules/ride_management/models/payment_method.dart';
import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

Person _user() => Person(
  id: 'user-1',
  name: 'Anna Secretary',
  email: 'anna@example.com',
  role: PersonRole.secretary,
  companyId: 'company-1',
  phone: '+490000000000',
);

void main() {
  late _MockAuthBloc authBloc;
  late MockRideService rideService;
  late RideBloc rideBloc;

  setUpAll(() => registerFallbackValue(TestFixtures.createRideRequest()));

  setUp(() {
    authBloc = _MockAuthBloc();
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_user()));
    rideService = MockRideService();
    when(() => rideService.dispose()).thenReturn(null);
    when(
      () => rideService.createRide(any()),
    ).thenAnswer((_) async => TestFixtures.ride());
    rideBloc = RideBloc(rideService: rideService);
  });

  tearDown(() => rideBloc.close());

  // Builds a form state with a complete, valid ride and the given payment method.
  CreateRideFormState formState(PaymentMethod method) =>
      CreateRideFormState.initial().copyWith(
        selectedClientId: 'client-1',
        clientName: 'Test Client',
        fromAddress: 'Marienplatz 1',
        toAddress: 'Airport T2',
        selectedPaymentMethod: method,
      );

  Future<CreateRideRequest> submitAndCapture(
    WidgetTester tester,
    PaymentMethod method,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: authBloc),
            BlocProvider<RideBloc>.value(value: rideBloc),
            BlocProvider<CreateRideFormBloc>(
              create: (_) => CreateRideFormBloc(),
            ),
          ],
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => CreateRideFormHelper.handleFormSubmission(
                context,
                formState(method),
              ),
              child: const Text('submit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('submit'));
    await tester.pump();

    final captured = verify(
      () => rideService.createRide(captureAny()),
    ).captured.single;
    return captured as CreateRideRequest;
  }

  testWidgets('forwards the selected payment method into the request', (
    tester,
  ) async {
    final request = await submitAndCapture(tester, PaymentMethod.cash);
    expect(request.paymentMethod, PaymentMethod.cash);
  });

  testWidgets('forwards the default Invoice method when unchanged', (
    tester,
  ) async {
    final request = await submitAndCapture(tester, PaymentMethod.invoice);
    expect(request.paymentMethod, PaymentMethod.invoice);
  });
}
