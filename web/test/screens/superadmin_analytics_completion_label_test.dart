// Regression: the SuperAdmin analytics tile was labelled "On-time" but its
// value is completed/total — a completion rate, not a punctuality metric. The
// label must read "Completion rate" so the number isn't misread as on-time %.

import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/screens/superadmin_analytics_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _MockApiClient extends Mock implements ApiClient {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

void main() {
  late _MockApiClient api;
  late _MockAuthBloc authBloc;

  setUp(() {
    api = _MockApiClient();
    authBloc = _MockAuthBloc();
    when(() => authBloc.apiClient).thenReturn(api);

    http.Response ok(Object body) => http.Response(jsonEncode(body), 200);
    // 10 rides total (across companies), 7 completed -> 70.0% completion rate.
    when(
      () => api.get(any(that: startsWith('/superadmin/analytics/rides'))),
    ).thenAnswer(
      (_) async => ok({
        'byStatus': {'Completed': 7, 'Cancelled': 3},
        'ridesByCompany': {'co-1': 6, 'co-2': 4},
        'totalRevenue': 0,
      }),
    );
    when(
      () => api.get(any(that: startsWith('/superadmin/analytics/billing'))),
    ).thenAnswer(
      (_) async =>
          ok({'totalRevenue': 0, 'invoiceCount': 0, 'overdueCount': 0}),
    );
    when(
      () => api.get('/superadmin/analytics/connections'),
    ).thenAnswer((_) async => ok({'activeSessions': 0}));
  });

  testWidgets('analytics shows a "Completion rate" tile, not "On-time"', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        home: Scaffold(
          body: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const SuperAdminAnalyticsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completion rate'), findsWidgets);
    expect(find.text('On-time'), findsNothing);
    // 7/10 = 70.0%
    expect(find.text('70.0 %'), findsWidgets);
  });
}
