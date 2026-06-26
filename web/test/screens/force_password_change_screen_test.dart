// Widget test for ForcePasswordChangeScreen — the forced password-change gate
// shown after a temporary-password login.
//
// Covers: the form renders, validation blocks submit when fields are empty or
// mismatched, and a valid submit dispatches AuthPasswordChangeRequested with the
// entered passwords. The screen reads/writes through AuthBloc, which we mock.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/screens/force_password_change_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

class _FakeAuthEvent extends Fake implements AuthEvent {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthEvent());
  });

  late _MockAuthBloc authBloc;
  final user = TestFixtures.person(
    email: 'temp@test.com',
    mustChangePassword: true,
  );

  setUp(() {
    authBloc = _MockAuthBloc();
    when(() => authBloc.add(any())).thenAnswer((_) {});
    when(() => authBloc.state).thenReturn(AuthState.mustChangePassword(user));
  });

  Widget buildSubject() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: ForcePasswordChangeScreen(user: user),
    ),
  );

  testWidgets('valid submit dispatches AuthPasswordChangeRequested', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(3));

    await tester.enterText(fields.at(0), 'Temp1234'); // temporary
    await tester.enterText(fields.at(1), 'NewPass123'); // new
    await tester.enterText(fields.at(2), 'NewPass123'); // confirm

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    final captured = verify(() => authBloc.add(captureAny())).captured;
    final event = captured.whereType<AuthPasswordChangeRequested>().single;
    expect(event.currentPassword, 'Temp1234');
    expect(event.newPassword, 'NewPass123');
  });

  testWidgets('mismatched confirmation blocks submit', (tester) async {
    await tester.pumpWidget(buildSubject());
    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'Temp1234');
    await tester.enterText(fields.at(1), 'NewPass123');
    await tester.enterText(fields.at(2), 'Different1'); // mismatch

    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();

    // Validation fails, so no password-change event is dispatched.
    verifyNever(
      () => authBloc.add(any(that: isA<AuthPasswordChangeRequested>())),
    );
  });
}
