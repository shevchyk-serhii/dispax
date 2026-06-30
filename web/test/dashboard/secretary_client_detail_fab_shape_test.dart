// Widget test for the "Neue Fahrt" extended FAB on the secretary
// ClientDetailScreen.
//
// The app theme sets a global `floatingActionButtonTheme.shape = CircleBorder()`
// (correct for the regular round FABs elsewhere). An extended FAB is a pill, so
// inheriting CircleBorder clips both the icon and the label. ClientDetailScreen
// therefore overrides the shape with `StadiumBorder()` locally.
//
// This test locks that override in: with the real app theme applied, the
// extended FAB's resolved shape must be a StadiumBorder, not the theme's
// CircleBorder.
//
// Mutation check: remove `shape: const StadiumBorder()` from the FAB -> it
// inherits the theme's CircleBorder -> this test goes red.

import 'dart:convert';

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
import 'package:dispax/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

// ─── Local fakes / mocks ─────────────────────────────────────────────────────

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _FakeRideEvent extends Fake implements RideEvent {}

// ─── Test data ───────────────────────────────────────────────────────────────

Person _client() => Person(
  id: 'client-1',
  name: 'Walk-in',
  email: 'provisional+abc@chat.dispax.local',
  role: PersonRole.client,
  companyId: 'company-1',
);

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
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
    // ClientDetailScreen calls GET /rides/client/{id} to load the ride list.
    when(
      () => api.get(any()),
    ).thenAnswer((_) async => http.Response(jsonEncode(<dynamic>[]), 200));
  });

  Widget host() => MaterialApp(
    // Use the real app theme so the global CircleBorder FAB shape is in effect;
    // the screen must override it locally for the extended FAB.
    theme: AppTheme.theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('de'),
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RideBloc>.value(value: rideBloc),
      ],
      child: ClientDetailScreen(client: _client()),
    ),
  );

  testWidgets(
    'extended "Neue Fahrt" FAB uses a StadiumBorder (not the theme CircleBorder)',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );

      expect(
        fab.shape,
        isA<StadiumBorder>(),
        reason:
            'an extended FAB must be a pill; without the local StadiumBorder '
            'override it inherits the theme CircleBorder and clips icon + label',
      );
    },
  );
}
