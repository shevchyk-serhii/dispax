// Regression: the stats-load error text used AppStyles.bodyMedium, whose
// hardcoded color is the light-theme AppColors.textPrimary (near-black). On the
// dark Scaffold the error was black-on-dark and invisible. It must resolve to
// the theme onSurface color so the failure is readable in dark mode.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/dashboard/secretary/widgets/secretary_reports_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
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
    when(() => authBloc.state).thenReturn(AuthState.initial());
  });

  testWidgets('stats-load error text uses theme onSurface color in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The panel loads stats on init; throw so the error branch renders.
    when(() => api.get(any())).thenThrow(Exception('boom'));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: BlocProvider<AuthBloc>.value(
            value: authBloc,
            child: const SecretaryReportsPanel(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

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
