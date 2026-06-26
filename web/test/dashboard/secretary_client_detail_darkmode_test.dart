// Regression: the client-detail header name used AppStyles.titleMedium and the
// ride-load error used AppStyles.bodyMedium — both carry the hardcoded
// light-theme AppColors.textPrimary (near-black). On the dark surface that text
// was black-on-dark and invisible. Both must now resolve to the theme onSurface
// color so they stay readable in dark mode.

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
  });

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locale: const Locale('en'),
    theme: AppTheme.darkTheme,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RideBloc>.value(value: rideBloc),
      ],
      child: ClientDetailScreen(client: _client()),
    ),
  );

  testWidgets('client name uses theme onSurface color in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The ride list loads on init; return an empty list so the header renders.
    when(
      () => api.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // The name renders twice: in the AppBar title (titleLarge, fontSize 22) and
    // in the body header (titleMedium, fontSize 18 — the one this fix touched).
    // Pick the body header by its titleMedium font size.
    final nameWidget = tester
        .widgetList<Text>(find.text('Bruno Aldi'))
        .firstWhere(
          (t) => t.style?.fontSize == 18,
          orElse: () => throw StateError('body header name Text not found'),
        );
    final context = tester.element(find.text('Bruno Aldi').first);
    final expected = Theme.of(context).colorScheme.onSurface;

    expect(nameWidget.style?.color, expected);
    expect(nameWidget.style?.color, isNot(const Color(0xFF18181B)));
  });

  testWidgets('ride-load error text uses theme onSurface color in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Make the ride load fail so the error branch renders.
    when(
      () => api.get(any()),
    ).thenAnswer((_) async => http.Response('boom', 500));

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // The error icon marks the error branch; grab the error message Text below it.
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    final errorText = tester
        .widgetList<Text>(find.byType(Text))
        .firstWhere(
          (t) => t.style?.fontSize == 14 && (t.data ?? '').isNotEmpty,
          orElse: () => throw StateError('error message Text not found'),
        );
    final context = tester.element(find.byIcon(Icons.error_outline));
    expect(errorText.style?.color, Theme.of(context).colorScheme.onSurface);
    expect(errorText.style?.color, isNot(const Color(0xFF18181B)));
  });
}
