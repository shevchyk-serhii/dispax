// Regression test for the "Clear Form" button rendering as a blank bordered
// box in dark mode on the Create Ride screen.
//
// Bug: CreateRideActionButtons hardcoded the buttons' foreground to
// AppColors.secretaryColor (== AppColors.primary, a near-black graphite). In
// the dark theme that graphite matched the dark surface, so the outlined
// "Clear Form" button's icon + label + border were invisible — leaving only a
// faint empty rectangle below the "Create Ride" button.
//
// Fix: read colors from the theme (colorScheme.primary / onPrimary), which the
// app inverts to a light foreground in dark mode. These tests assert the
// resolved foreground is the theme color (visible) and NOT the graphite.

import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/modules/ride_management/widgets/create_ride_action_buttons.dart';
import 'package:dispax/theme/app_theme.dart';

Widget _wrap(Widget child, {required Brightness brightness}) {
  const delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  const supportedLocales = [Locale('en'), Locale('de')];
  // Mount under the REAL app theme so colorScheme.primary resolves exactly as
  // it does in the app (light graphite in dark mode, graphite in light mode).
  return MaterialApp(
    localizationsDelegates: delegates,
    supportedLocales: supportedLocales,
    theme: AppTheme.theme,
    darkTheme: AppTheme.darkTheme,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: BlocProvider<CreateRideFormBloc>(
      create: (_) => CreateRideFormBloc(),
      child: Scaffold(
        body: CreateRideActionButtons(onCreateRide: () {}, onClearForm: () {}),
      ),
    ),
  );
}

/// Resolves the effective foreground color of the [OutlinedButton] whose label
/// is "Clear Form".
Color? _clearFormForeground(WidgetTester tester) {
  final button = tester.widget<OutlinedButton>(
    find.ancestor(
      of: find.text('Clear Form'),
      matching: find.byType(OutlinedButton),
    ),
  );
  return button.style?.foregroundColor?.resolve(<WidgetState>{});
}

ColorScheme _scheme(WidgetTester tester) {
  final context = tester.element(find.byType(CreateRideActionButtons));
  return Theme.of(context).colorScheme;
}

void main() {
  testWidgets(
    'Clear Form button uses the theme primary (visible) in dark mode, not '
    'the graphite AppColors.primary',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();

      final scheme = _scheme(tester);
      final fg = _clearFormForeground(tester);

      // The fix: foreground follows the theme...
      expect(fg, scheme.primary);
      // ...and the theme's dark primary is the light foreground, NOT the
      // graphite that caused the blank-box bug.
      expect(scheme.primary, AppColors.textPrimaryDark);
      expect(
        fg,
        isNot(AppColors.primary),
        reason: 'graphite foreground on a dark surface is the invisible bug',
      );
    },
  );

  testWidgets('Clear Form button stays graphite in light mode (unchanged)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const SizedBox(), brightness: Brightness.light),
    );
    await tester.pumpAndSettle();

    final scheme = _scheme(tester);
    final fg = _clearFormForeground(tester);

    expect(fg, scheme.primary);
    expect(scheme.primary, AppColors.primary); // light theme keeps graphite
  });
}
