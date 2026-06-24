// Regression: the secretary client-detail edit dialog fired updateClient() with
// a fire-and-forget `.then()` — on failure the error was dropped, the dialog
// closed anyway (user thinks it saved), and setState could run after dispose.
// The fix awaits the call, shows success/failure snackbars, and keeps the
// dialog open on error.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/secretary/widgets/client_detail_screen.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _FakeRideEvent extends Fake implements RideEvent {}

Person _client() => Person(
  id: 'client-1',
  name: 'Bruno Aldi',
  email: 'bruno@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
  phone: '+491234567890',
);

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(_FakeRideEvent());
  });

  late _MockApiClient api;
  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;

  setUp(() {
    api = _MockApiClient();
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    when(() => authBloc.apiClient).thenReturn(api);
    when(() => authBloc.state).thenReturn(AuthState.authenticated(_client()));
    when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
    when(() => rideBloc.add(any())).thenAnswer((_) {});
    // client-detail loads this client's rides on init.
    when(
      () => api.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));
  });

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locale: const Locale('en'),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RideBloc>.value(value: rideBloc),
      ],
      child: ClientDetailScreen(client: _client()),
    ),
  );

  Future<void> openEditAndSave(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // Open the edit dialog via the edit icon in the app bar.
    await tester.tap(find.byIcon(Icons.edit).first);
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.tap(find.widgetWithText(ElevatedButton, l10n.save));
    await tester.pumpAndSettle();
  }

  testWidgets('a failed update keeps the dialog open and shows an error', (
    tester,
  ) async {
    when(
      () => api.put(any(), any()),
    ).thenAnswer((_) async => http.Response('nope', 500));

    await openEditAndSave(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // Dialog stays open (the Save button is still in the tree).
    expect(find.widgetWithText(ElevatedButton, l10n.save), findsOneWidget);
    // Error surfaced.
    expect(find.text(l10n.clientUpdateFailed), findsOneWidget);
  });

  testWidgets('a successful update closes the dialog and confirms', (
    tester,
  ) async {
    when(() => api.put(any(), any())).thenAnswer(
      (_) async => http.Response(
        '{"id":"client-1","name":"Bruno Aldi","email":"bruno@example.com",'
        '"role":"client","companyId":"company-1","phone":"+491234567890",'
        '"isVip":true}',
        200,
      ),
    );

    await openEditAndSave(tester);

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    // Dialog closed.
    expect(find.widgetWithText(ElevatedButton, l10n.save), findsNothing);
    // Success surfaced.
    expect(find.text(l10n.clientUpdatedSuccess), findsOneWidget);
  });
}
