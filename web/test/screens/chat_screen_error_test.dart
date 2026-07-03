// Regressions for the ride-chat error handling. ApiClient returns non-2xx
// responses instead of throwing, so:
//  - a 403 from the backend participation guard used to leave the screen on an
//    infinite spinner (_loadMessages only handled 200);
//  - a rejected send (400 validation / 403 not a party) used to silently
//    discard the typed message (cleared before the POST, status never checked).

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/ride_management/models/ride.dart';
import 'package:dispax/screens/chat_screen.dart';

import '../helpers/mocks.dart';
import '../helpers/test_fixtures.dart';

void main() {
  late MockApiClient mockApiClient;
  late AuthBloc authBloc;

  final ride = TestFixtures.ride(
    id: 'ride-1',
    status: RideStatus.assigned,
    driverId: 'driver-1',
  );

  setUp(() {
    mockApiClient = MockApiClient();
    authBloc = AuthBloc(apiClient: mockApiClient);
  });

  tearDown(() {
    authBloc.close();
  });

  Widget buildScreen() => BlocProvider<AuthBloc>.value(
    value: authBloc,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChatScreen(ride: ride),
    ),
  );

  Future<AppLocalizations> l10nEn() =>
      AppLocalizations.delegate.load(const Locale('en'));

  testWidgets('403 on load shows an error state with Retry, not an infinite '
      'spinner', (tester) async {
    when(
      () => mockApiClient.get('/rides/ride-1/chat'),
    ).thenAnswer((_) async => http.Response('{"error":"Access denied"}', 403));

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    final l10n = await l10nEn();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text(l10n.errorLoadingData), findsOneWidget);
    expect(find.text(l10n.retry), findsOneWidget);
  });

  testWidgets('Retry after a failed load reloads the thread', (tester) async {
    var calls = 0;
    when(() => mockApiClient.get('/rides/ride-1/chat')).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? http.Response('{"error":"boom"}', 500)
          : http.Response('[]', 200);
    });

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    final l10n = await l10nEn();
    await tester.tap(find.text(l10n.retry));
    await tester.pump();
    await tester.pump();

    expect(find.text(l10n.retry), findsNothing);
    expect(find.text(l10n.noMessages), findsOneWidget);
  });

  testWidgets('a rejected send keeps the typed text and shows a snackbar', (
    tester,
  ) async {
    when(
      () => mockApiClient.get('/rides/ride-1/chat'),
    ).thenAnswer((_) async => http.Response('[]', 200));
    when(
      () => mockApiClient.post('/rides/ride-1/chat', any()),
    ).thenAnswer((_) async => http.Response('{"error":"Access denied"}', 403));

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello driver');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    final l10n = await l10nEn();
    expect(
      find.textContaining(l10n.failedToSendMessage('').trim()),
      findsOneWidget,
      reason: 'A rejected send must surface a snackbar, not vanish silently.',
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(
      field.controller?.text,
      'Hello driver',
      reason: 'The typed message must survive a rejected send.',
    );
  });

  testWidgets('an accepted send clears the input field', (tester) async {
    when(
      () => mockApiClient.get('/rides/ride-1/chat'),
    ).thenAnswer((_) async => http.Response('[]', 200));
    when(
      () => mockApiClient.post('/rides/ride-1/chat', any()),
    ).thenAnswer((_) async => http.Response('{}', 201));

    await tester.pumpWidget(buildScreen());
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'Hello driver');
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump();
    await tester.pump();

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, isEmpty);
  });
}
