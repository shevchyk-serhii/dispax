// Regression test for the Create-Ride action buttons (Create Ride + Clear Form)
// being invisible / inconsistent across themes.
//
// Root cause: the create-ride form body sits on an ALWAYS-dark graphite gradient
// (AppColors.secretaryGradient == Color(0xFF18181B) in both themes). Every other
// section wraps its content in a colorScheme.surface card, but the action buttons
// used to sit bare on that dark gradient. Their colors come from
// colorScheme.primary, which is graphite (#18181B) in LIGHT mode — so on the
// dark gradient the outlined "Clear Form" button (graphite text + graphite
// border) was graphite-on-graphite and vanished, while "Create Ride"'s graphite
// fill blended into the background (only its white label showed). In DARK mode
// primary is near-white, so the buttons happened to be visible — which is why the
// form "looked different" depending on the device theme (and so seemed to differ
// between driver and dispatcher, who share the exact same form).
//
// Fix: CreateRideActionsSection now wraps the buttons in a colorScheme.surface
// card (like every other section), so primary contrasts in BOTH themes.
//
// These tests pump CreateRideActionsSection inside the real dark form gradient
// and assert the buttons contrast with their immediate surface in both themes,
// plus that the surface wrapper is present (the actual fix).

import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/modules/ride_management/widgets/create_ride_action_buttons.dart';
import 'package:dispax/modules/ride_management/widgets/sections/create_ride_actions_section.dart';
import 'package:dispax/theme/app_theme.dart';

const _graphite = Color(0xFF18181B); // form gradient background, both themes

final _formKey = GlobalKey<FormState>();

/// Pumps [CreateRideActionsSection] inside the SAME always-dark graphite
/// gradient the real form body uses, under the real app theme, so the buttons'
/// surface wrapper and color resolution mirror production.
Widget _wrap({required Brightness brightness}) {
  const delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  const supportedLocales = [Locale('en'), Locale('de')];
  return MaterialApp(
    localizationsDelegates: delegates,
    supportedLocales: supportedLocales,
    theme: AppTheme.theme,
    darkTheme: AppTheme.darkTheme,
    themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
    home: BlocProvider<CreateRideFormBloc>(
      create: (_) => CreateRideFormBloc(),
      child: Scaffold(
        body: AppTheme.buildGradientContainer(
          colors: AppColors.secretaryGradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: CreateRideActionsSection(formKey: _formKey),
            ),
          ),
        ),
      ),
    ),
  );
}

Color? _clearFormForeground(WidgetTester tester) {
  final button = tester.widget<OutlinedButton>(
    find.ancestor(
      of: find.text('Clear Form'),
      matching: find.byType(OutlinedButton),
    ),
  );
  return button.style?.foregroundColor?.resolve(<WidgetState>{});
}

Color? _clearFormBorderColor(WidgetTester tester) {
  final button = tester.widget<OutlinedButton>(
    find.ancestor(
      of: find.text('Clear Form'),
      matching: find.byType(OutlinedButton),
    ),
  );
  return button.style?.side?.resolve(<WidgetState>{})?.color;
}

Color? _createRideBackground(WidgetTester tester) {
  final button = tester.widget<ElevatedButton>(
    find.ancestor(
      of: find.text('Create Ride'),
      matching: find.byType(ElevatedButton),
    ),
  );
  return button.style?.backgroundColor?.resolve(<WidgetState>{});
}

ColorScheme _scheme(WidgetTester tester) {
  final context = tester.element(find.byType(CreateRideActionButtons));
  return Theme.of(context).colorScheme;
}

/// The fill of the nearest [Container]/[DecoratedBox] surface card wrapping the
/// buttons — null if no such surface wrapper exists (the bug condition).
Color? _surroundingSurface(WidgetTester tester, ColorScheme scheme) {
  final decorations = tester
      .widgetList<DecoratedBox>(
        find.ancestor(
          of: find.byType(CreateRideActionButtons),
          matching: find.byType(DecoratedBox),
        ),
      )
      .map((d) => d.decoration)
      .whereType<BoxDecoration>();
  for (final d in decorations) {
    if (d.color == scheme.surface) return d.color;
  }
  return null;
}

void main() {
  testWidgets(
    'Clear Form button contrasts with its surface in dark mode (visible)',
    (tester) async {
      await tester.pumpWidget(_wrap(brightness: Brightness.dark));
      await tester.pumpAndSettle();

      final scheme = _scheme(tester);
      final fg = _clearFormForeground(tester);
      final border = _clearFormBorderColor(tester);

      // Theme-aware, and — crucially — NOT the graphite that equals the dark
      // form gradient behind the card.
      expect(fg, scheme.primary);
      expect(scheme.primary, AppColors.textPrimaryDark);
      expect(
        fg,
        isNot(_graphite),
        reason: 'graphite foreground would vanish on the dark gradient',
      );
      expect(border, isNot(_graphite));
      expect(
        fg,
        isNot(scheme.surface),
        reason: 'foreground must contrast with its surface card',
      );
    },
  );

  testWidgets(
    'Clear Form button contrasts with its surface in light mode (visible)',
    (tester) async {
      await tester.pumpWidget(_wrap(brightness: Brightness.light));
      await tester.pumpAndSettle();

      final scheme = _scheme(tester);
      final fg = _clearFormForeground(tester);

      // In light mode primary is graphite — acceptable ONLY because it sits on
      // a white surface card, not on the dark gradient. Assert that contrast:
      // the foreground differs from its surface, and the surface is NOT the dark
      // gradient (i.e. the surface wrapper is doing its job).
      expect(fg, scheme.primary);
      expect(
        fg,
        isNot(scheme.surface),
        reason: 'graphite foreground must sit on a non-graphite surface',
      );
      expect(
        scheme.surface,
        isNot(_graphite),
        reason: 'light surface card must differ from the dark gradient',
      );
    },
  );

  testWidgets(
    'Create Ride button is present and theme-colored in both themes',
    (tester) async {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        await tester.pumpWidget(_wrap(brightness: brightness));
        await tester.pumpAndSettle();

        final scheme = _scheme(tester);
        expect(
          find.ancestor(
            of: find.text('Create Ride'),
            matching: find.byType(ElevatedButton),
          ),
          findsOneWidget,
        );
        expect(_createRideBackground(tester), scheme.primary);
      }
    },
  );

  testWidgets('action buttons are wrapped in a colorScheme.surface card', (
    tester,
  ) async {
    // Regression guard for the fix: removing the surface wrapper makes this and
    // the contrast assertions go red (graphite primary on the dark gradient).
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(_wrap(brightness: brightness));
      await tester.pumpAndSettle();

      final scheme = _scheme(tester);
      expect(
        _surroundingSurface(tester, scheme),
        scheme.surface,
        reason:
            'buttons must sit on a surface card, not the bare dark gradient',
      );
    }
  });
}
