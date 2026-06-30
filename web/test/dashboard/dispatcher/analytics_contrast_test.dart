import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/dashboard/dispatcher/widgets/analytics_panel.dart';
import 'package:dispax/dashboard/dispatcher/widgets/client_value_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _dispatcher() => Person(
  id: 'disp-1',
  name: 'Dispatcher Anna',
  email: 'disp@example.com',
  role: PersonRole.dispatcher,
  companyId: 'company-1',
  phone: '+491234567890',
  roles: {PersonRole.dispatcher},
);

/// The static graphite that made these values invisible in dark mode.
const _graphite = AppColors.primary; // 0xFF18181B

void main() {
  late _MockAuthBloc authBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    apiClient = _MockApiClient();
    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(
      () => authBloc.state,
    ).thenReturn(AuthState.authenticated(_dispatcher()));
  });

  Widget wrap(Widget panel, ThemeData theme) => MaterialApp(
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: BlocProvider<AuthBloc>.value(value: authBloc, child: panel),
    ),
  );

  /// The bold value [Text] inside a stat tile/row that renders [value].
  Color? valueColorOf(WidgetTester tester, String value) {
    final texts = tester.widgetList<Text>(find.text(value));
    final boldValue = texts.firstWhere(
      (t) => t.style?.fontWeight == FontWeight.bold,
      orElse: () => throw StateError('No bold Text "$value" found'),
    );
    return boldValue.style?.color;
  }

  group('AnalyticsPanel metric values are theme-aware (not dark-on-dark)', () {
    setUp(() {
      // Unique counts so each value Text is unambiguous: drivers 7, clients 42.
      when(() => apiClient.get('/stats/rides')).thenAnswer(
        (_) async => http.Response(
          jsonEncode({
            'totalRides': 13,
            'completedRides': 9,
            'cancelledRides': 1,
            'inProgressRides': 2,
            'requestedRides': 3,
            'assignedRides': 5,
            'activeDrivers': 7,
            'totalClients': 42,
            'todayRevenue': 0,
            'monthlyRevenue': 262,
            'avgAssignmentMinutes': 53,
          }),
          200,
        ),
      );
      when(
        () => apiClient.get('/stats/rides/daily?days=7'),
      ).thenAnswer((_) async => http.Response('[]', 200));
    });

    testWidgets('dark theme: Active Drivers / Total Clients use primary, '
        'not graphite', (tester) async {
      await tester.pumpWidget(wrap(const AnalyticsPanel(), AppTheme.darkTheme));
      await tester.pumpAndSettle();

      final darkPrimary = AppTheme.darkTheme.colorScheme.primary;
      expect(valueColorOf(tester, '7'), darkPrimary); // Active Drivers
      expect(valueColorOf(tester, '42'), darkPrimary); // Total Clients
      // Guard against the regression: graphite would be invisible here.
      expect(valueColorOf(tester, '7'), isNot(_graphite));
      expect(valueColorOf(tester, '42'), isNot(_graphite));
    });

    testWidgets('light theme: values track colorScheme.primary', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const AnalyticsPanel(), AppTheme.theme));
      await tester.pumpAndSettle();

      final lightPrimary = AppTheme.theme.colorScheme.primary;
      expect(valueColorOf(tester, '7'), lightPrimary);
      expect(valueColorOf(tester, '42'), lightPrimary);
    });
  });

  group('ClientValuePanel summary "Clients" tile is theme-aware', () {
    setUp(() {
      // 3 clients → count "3"; revenues sum to 170, avg 56 — all distinct.
      when(() => apiClient.get('/stats/client-value')).thenAnswer(
        (_) async => http.Response(
          jsonEncode([
            {'clientName': 'BMW AG', 'totalRevenue': 100, 'rideCount': 1},
            {'clientName': 'Allianz', 'totalRevenue': 50, 'rideCount': 1},
            {'clientName': 'Siemens', 'totalRevenue': 20, 'rideCount': 1},
          ]),
          200,
        ),
      );
    });

    testWidgets('dark theme: Clients count uses primary, not graphite', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(const ClientValuePanel(), AppTheme.darkTheme),
      );
      await tester.pumpAndSettle();

      final darkPrimary = AppTheme.darkTheme.colorScheme.primary;
      expect(valueColorOf(tester, '3'), darkPrimary); // Clients count
      expect(valueColorOf(tester, '3'), isNot(_graphite));
    });

    testWidgets('light theme: Clients count tracks colorScheme.primary', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const ClientValuePanel(), AppTheme.theme));
      await tester.pumpAndSettle();

      final lightPrimary = AppTheme.theme.colorScheme.primary;
      expect(valueColorOf(tester, '3'), lightPrimary);
    });
  });
}
