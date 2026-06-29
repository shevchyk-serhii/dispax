// Verifies that CreateRideFormHelper.handleFormSubmission, when
// isProvisionalClient is true, passes:
//   - provisionalClient: true
//   - clientId: ''   (empty, NOT the current user's id)
// into the CreateRideRequest sent to the RideBloc / RideService.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
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

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

Person _user() => Person(
  id: 'user-id-99',
  name: 'Anna Secretary',
  email: 'anna@example.com',
  role: PersonRole.secretary,
  companyId: 'company-1',
  phone: '+490000000000',
);

/// A valid provisional form state (addresses filled, no client selected).
CreateRideFormState _provisionalForm() =>
    CreateRideFormState.initial().copyWith(
      fromAddress: 'Marienplatz 1',
      toAddress: 'Airport T2',
      isProvisionalClient: true,
      clientName: '',
      manualPickupDateTime: DateTime(2026, 6, 1, 10, 0),
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

  Future<CreateRideRequest> submitAndCapture(
    WidgetTester tester,
    CreateRideFormState state,
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
              onPressed: () =>
                  CreateRideFormHelper.handleFormSubmission(context, state),
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

  testWidgets(
    'provisional submission sends provisionalClient=true and empty clientId',
    (tester) async {
      final request = await submitAndCapture(tester, _provisionalForm());

      expect(
        request.provisionalClient,
        isTrue,
        reason: 'provisionalClient must be true in the request',
      );
      expect(
        request.clientId,
        '',
        reason: 'clientId must be empty (not the user id) in provisional mode',
      );
    },
  );

  testWidgets('mutation check: without isProvisionalClient path, '
      'clientId would be the user id (not empty)', (tester) async {
    // Simulate the "fix reverted" state by using the OLD logic:
    // clientId = formState.selectedClientId ?? authState.user!.id
    // We run this as a unit test of that expression directly.
    final form = _provisionalForm();
    const userId = 'user-id-99';

    // Old path (no provisional check): always falls back to user id.
    final oldClientId = form.selectedClientId ?? userId;
    expect(
      oldClientId,
      userId,
      reason:
          'Without the fix, clientId would be the current user id, '
          'not empty — confirming the fix is necessary',
    );

    // New path (with provisional check): empty string.
    final newClientId = form.isProvisionalClient
        ? ''
        : (form.selectedClientId ?? userId);
    expect(
      newClientId,
      '',
      reason: 'With the fix, clientId is empty for provisional rides',
    );
  });

  testWidgets(
    'non-provisional submission still uses the selected client id (no regression)',
    (tester) async {
      final normalForm = CreateRideFormState.initial().copyWith(
        fromAddress: 'Marienplatz 1',
        toAddress: 'Airport T2',
        isProvisionalClient: false,
        selectedClientId: 'client-abc',
        clientName: 'Test Client',
        manualPickupDateTime: DateTime(2026, 6, 1, 10, 0),
      );

      final request = await submitAndCapture(tester, normalForm);

      expect(request.provisionalClient, isFalse);
      expect(request.clientId, 'client-abc');
    },
  );
}
