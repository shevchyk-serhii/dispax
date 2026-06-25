// Tests for CalendarControls — the date navigation header used by the
// dispatcher/driver/client calendar screens.
//
// Regressions covered:
//   1. Date text and chevrons were hard-coded Colors.white, so on the light
//      Scaffold body of the calendar screens the header was invisible (white on
//      white). They must now follow the theme (onSurface / onSurfaceVariant) so
//      they are visible in both light and dark.
//   2. Day/month names were hard-coded English, so a German user saw "Thursday"
//      instead of "Donnerstag". The label must now be localized via DateFormat
//      with the active locale.

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/widgets/calendar_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 2026-06-25 is a Thursday / Donnerstag.
final _thursday = DateTime(2026, 6, 25);

/// Pumps CalendarControls and captures the resolved theme colors from the same
/// subtree so the assertions compare against the real ColorScheme, not a guess.
Future<({Color onSurface, Color onSurfaceVariant})> _pump(
  WidgetTester tester, {
  required CalendarViewType viewType,
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
  VoidCallback? onPrevious,
  VoidCallback? onNext,
  VoidCallback? onTap,
}) async {
  late ColorScheme scheme;
  Widget controls = Builder(
    builder: (context) {
      scheme = Theme.of(context).colorScheme;
      return CalendarControls(
        selectedDay: _thursday,
        viewType: viewType,
        onPrevious: onPrevious ?? () {},
        onNext: onNext ?? () {},
        onDatePickerTap: onTap ?? () {},
      );
    },
  );

  if (brightness == Brightness.dark) {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        theme: ThemeData(useMaterial3: true),
        darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
        themeMode: ThemeMode.dark,
        home: Scaffold(body: controls),
      ),
    );
  } else {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        theme: ThemeData(brightness: Brightness.light, useMaterial3: true),
        home: Scaffold(body: controls),
      ),
    );
  }
  await tester.pumpAndSettle();
  return (
    onSurface: scheme.onSurface,
    onSurfaceVariant: scheme.onSurfaceVariant,
  );
}

Text _dateText(WidgetTester tester) {
  // The only multi-word Text in the widget is the date label.
  return tester.widget<Text>(
    find.byType(Text).first,
  );
}

List<Icon> _chevrons(WidgetTester tester) =>
    tester.widgetList<Icon>(find.byType(Icon)).toList();

void main() {
  group('CalendarControls — visibility (theme-aware colors)', () {
    testWidgets('light mode: date text uses onSurface, not white', (
      tester,
    ) async {
      final theme = await _pump(tester, viewType: CalendarViewType.day);
      final color = _dateText(tester).style!.color;
      expect(
        color,
        theme.onSurface,
        reason:
            'date label must use colorScheme.onSurface so it is visible on the '
            'light Scaffold body (was hard-coded Colors.white = invisible)',
      );
      expect(color, isNot(Colors.white));
    });

    testWidgets('dark mode: date text uses onSurface', (tester) async {
      final theme = await _pump(
        tester,
        viewType: CalendarViewType.day,
        brightness: Brightness.dark,
      );
      expect(_dateText(tester).style!.color, theme.onSurface);
    });

    testWidgets('chevrons use onSurfaceVariant, not white', (tester) async {
      final theme = await _pump(tester, viewType: CalendarViewType.day);
      final colors = _chevrons(tester).map((i) => i.color).toSet();
      expect(colors, {theme.onSurfaceVariant});
      expect(colors.contains(Colors.white), isFalse);
    });
  });

  group('CalendarControls — localized date label', () {
    testWidgets('English day view shows English weekday', (tester) async {
      await _pump(tester, viewType: CalendarViewType.day);
      expect(find.textContaining('Thursday'), findsOneWidget);
    });

    testWidgets('German day view shows German weekday (Donnerstag)', (
      tester,
    ) async {
      await _pump(
        tester,
        viewType: CalendarViewType.day,
        locale: const Locale('de'),
      );
      expect(find.textContaining('Donnerstag'), findsOneWidget);
      expect(find.textContaining('Thursday'), findsNothing);
    });

    testWidgets('German month view shows German month (Juni)', (tester) async {
      await _pump(
        tester,
        viewType: CalendarViewType.month,
        locale: const Locale('de'),
      );
      expect(find.textContaining('Juni'), findsOneWidget);
    });

    testWidgets('multiColumn view shows the full localized date', (
      tester,
    ) async {
      await _pump(
        tester,
        viewType: CalendarViewType.multiColumn,
        locale: const Locale('de'),
      );
      expect(find.textContaining('Donnerstag'), findsOneWidget);
    });
  });

  group('CalendarControls — callbacks', () {
    testWidgets('previous chevron fires onPrevious', (tester) async {
      var fired = false;
      await _pump(
        tester,
        viewType: CalendarViewType.day,
        onPrevious: () => fired = true,
      );
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(fired, isTrue);
    });

    testWidgets('next chevron fires onNext', (tester) async {
      var fired = false;
      await _pump(
        tester,
        viewType: CalendarViewType.day,
        onNext: () => fired = true,
      );
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(fired, isTrue);
    });

    testWidgets('tapping the date fires onDatePickerTap', (tester) async {
      var fired = false;
      await _pump(
        tester,
        viewType: CalendarViewType.day,
        onTap: () => fired = true,
      );
      await tester.tap(find.byType(Text).first);
      await tester.pump();
      expect(fired, isTrue);
    });
  });
}
