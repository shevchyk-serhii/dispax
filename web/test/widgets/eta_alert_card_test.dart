import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/dashboard/dispatcher/widgets/eta_alert_card.dart';
import 'package:dispax/constants/lucide_compat.dart';
import 'package:dispax/constants/app_colors.dart';

Widget _wrap(
  Widget child, {
  Brightness brightness = Brightness.light,
  Locale locale = const Locale('en'),
}) {
  // Use darkTheme + ThemeMode.dark so that Theme.of(context).brightness
  // actually returns Brightness.dark inside the widget tree.
  const delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];
  const supportedLocales = [Locale('en'), Locale('de')];
  if (brightness == Brightness.dark) {
    return MaterialApp(
      localizationsDelegates: delegates,
      supportedLocales: supportedLocales,
      locale: locale,
      theme: ThemeData(useMaterial3: true),
      darkTheme: ThemeData(brightness: Brightness.dark, useMaterial3: true),
      themeMode: ThemeMode.dark,
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
  return MaterialApp(
    localizationsDelegates: delegates,
    supportedLocales: supportedLocales,
    locale: locale,
    theme: ThemeData(brightness: brightness, useMaterial3: true),
    home: Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: child),
    ),
  );
}

const _info = EtaAtRiskInfo(
  rideId: 'ride-1',
  driverName: 'Hans Müller',
  etaMinutes: 12,
  pickupInMinutes: 7,
  slackMinutes: -5,
);

void main() {
  group('EtaAlertCard — text rendering', () {
    testWidgets('renders driver name', (tester) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: _info)));
      expect(find.text('Hans Müller'), findsOneWidget);
    });

    testWidgets('renders negative slack minutes', (tester) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: _info)));
      expect(find.textContaining('Slack -5min'), findsOneWidget);
    });

    testWidgets('renders eta minutes in subtitle', (tester) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: _info)));
      expect(find.textContaining('ETA 12min'), findsOneWidget);
    });

    testWidgets('renders pickup-in minutes in subtitle', (tester) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: _info)));
      expect(find.textContaining('Pickup in 7min'), findsOneWidget);
    });

    testWidgets('renders zero slack correctly', (tester) async {
      const zeroSlack = EtaAtRiskInfo(
        rideId: 'r',
        driverName: 'Driver',
        etaMinutes: 5,
        pickupInMinutes: 5,
        slackMinutes: 0,
      );
      await tester.pumpWidget(_wrap(EtaAlertCard(info: zeroSlack)));
      expect(find.textContaining('Slack 0min'), findsOneWidget);
    });
  });

  group('EtaAlertCard — callbacks', () {
    testWidgets('onDismiss fires when X button is tapped', (tester) async {
      bool dismissed = false;
      await tester.pumpWidget(
        _wrap(EtaAlertCard(info: _info, onDismiss: () => dismissed = true)),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(dismissed, isTrue);
    });

    testWidgets('onReassign fires when "Reassign" button is tapped', (
      tester,
    ) async {
      bool reassigned = false;
      await tester.pumpWidget(
        _wrap(EtaAlertCard(info: _info, onReassign: () => reassigned = true)),
      );
      await tester.tap(find.text('Reassign'));
      await tester.pump();
      expect(reassigned, isTrue);
    });

    testWidgets('onView fires when "View" button is tapped', (tester) async {
      bool viewed = false;
      await tester.pumpWidget(
        _wrap(EtaAlertCard(info: _info, onView: () => viewed = true)),
      );
      await tester.tap(find.text('View'));
      await tester.pump();
      expect(viewed, isTrue);
    });

    testWidgets('"Reassign" button is absent when onReassign is null', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: _info)));
      expect(find.text('Reassign'), findsNothing);
    });

    testWidgets('"View" button is absent when onView is null', (tester) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: _info)));
      expect(find.text('View'), findsNothing);
    });

    testWidgets('dismiss IconButton is absent when onDismiss is null', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: _info)));
      expect(find.byType(IconButton), findsNothing);
    });

    testWidgets('all three callbacks can fire independently', (tester) async {
      bool dismissed = false;
      bool reassigned = false;
      bool viewed = false;
      await tester.pumpWidget(
        _wrap(
          EtaAlertCard(
            info: _info,
            onDismiss: () => dismissed = true,
            onReassign: () => reassigned = true,
            onView: () => viewed = true,
          ),
        ),
      );

      await tester.tap(find.text('Reassign'));
      await tester.pump();
      expect(reassigned, isTrue);
      expect(dismissed, isFalse);
      expect(viewed, isFalse);

      await tester.tap(find.text('View'));
      await tester.pump();
      expect(viewed, isTrue);
      expect(dismissed, isFalse);

      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(dismissed, isTrue);
    });
  });

  group('EtaAlertCard — icon identity', () {
    testWidgets('warning icon uses LucideCompat.alertTriangle', (tester) async {
      await tester.pumpWidget(_wrap(EtaAlertCard(info: _info)));

      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();

      expect(
        icons.contains(LucideCompat.alertTriangle),
        isTrue,
        reason:
            'EtaAlertCard must use LucideCompat.alertTriangle for the warning icon',
      );
    });

    testWidgets('dismiss button uses LucideCompat.x icon', (tester) async {
      await tester.pumpWidget(
        _wrap(EtaAlertCard(info: _info, onDismiss: () {})),
      );

      final icons = tester
          .widgetList<Icon>(find.byType(Icon))
          .map((i) => i.icon)
          .toList();

      expect(
        icons.contains(LucideCompat.x),
        isTrue,
        reason: 'dismiss button must use LucideCompat.x',
      );
    });
  });

  group('EtaAlertCard — background colour (alpha)', () {
    // Colour channel matching using the non-deprecated API (.r/.g/.b/.a).
    bool isErrorColour(Color col) =>
        (col.r - AppColors.error.r).abs() < 0.01 &&
        (col.g - AppColors.error.g).abs() < 0.01 &&
        (col.b - AppColors.error.b).abs() < 0.01;

    bool findBgWithAlpha(
      WidgetTester tester,
      double minAlpha,
      double maxAlpha,
    ) {
      for (final c in tester.widgetList<Container>(find.byType(Container))) {
        final deco = c.decoration;
        if (deco is BoxDecoration && deco.color != null) {
          final col = deco.color!;
          if (isErrorColour(col) && col.a >= minAlpha && col.a <= maxAlpha) {
            return true;
          }
        }
      }
      return false;
    }

    testWidgets(
      'light mode: outer Container has error colour with lower alpha (0.06)',
      (tester) async {
        await tester.pumpWidget(_wrap(EtaAlertCard(info: _info)));

        expect(
          findBgWithAlpha(tester, 0.04, 0.09),
          isTrue,
          reason:
              'light-mode background should use error colour with alpha≈0.06',
        );
      },
    );

    testWidgets('dark-mode: outer Container has error colour with alpha=0.12', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EtaAlertCard(info: _info), brightness: Brightness.dark),
      );

      expect(
        findBgWithAlpha(tester, 0.10, 0.15),
        isTrue,
        reason:
            'dark-mode background must use error colour at alpha≈0.12 '
            '(higher than light-mode 0.06); '
            'ensure _wrap uses darkTheme+ThemeMode.dark so brightness is Brightness.dark',
      );
    });
  });

  group('EtaAlertCard — layout (narrow / German)', () {
    // Regression for the title rendering one character per line: on a phone the
    // long DE title and the long DE badge competed for one Row, leaving the
    // title a few pixels of width so it collapsed into a vertical column of
    // letters. The title and badge must now live on separate lines.

    // Localised DE strings, pulled from AppLocalizations rather than hardcoded.
    Future<(String title, String badge)> deStrings(WidgetTester tester) async {
      late String title;
      late String badge;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context)!;
              title = l10n.rideAtRiskTitle;
              badge = l10n.etaMonitorBadgeLabel;
              return const SizedBox.shrink();
            },
          ),
          locale: const Locale('de'),
        ),
      );
      return (title, badge);
    }

    testWidgets('title renders as a couple of lines, not one letter per line', (
      tester,
    ) async {
      final (title, _) = await deStrings(tester);

      await tester.pumpWidget(
        _wrap(
          const SizedBox(width: 360, child: EtaAlertCard(info: _info)),
          locale: const Locale('de'),
        ),
      );

      // The DE title must word-wrap into at most a couple of lines. With the old
      // title+badge Row the title was squeezed to a few pixels of width and
      // collapsed into a vertical column of letters — a height of hundreds of
      // pixels. A single line at fontSize 15 is ~20px; cap generously at 3 lines.
      final titleHeight = tester.getSize(find.text(title)).height;
      expect(
        titleHeight,
        lessThan(70),
        reason:
            'DE title "$title" must wrap by word into at most a couple of lines, '
            'not one character per line',
      );

      // No RenderFlex/text overflow may be left pending after layout. The benign
      // "locale de unsupported by all delegates" warning is gone now that
      // GlobalCupertinoLocalizations.delegate is registered in _wrap.
      expect(tester.takeException(), isNull);
    });
  });

  group('EtaAlertCard — dark-mode readability', () {
    testWidgets('at-risk title is light (not dark errorStrong) in dark mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EtaAlertCard(info: _info), brightness: Brightness.dark),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text('Ride at risk of delay'));
      // On the dark translucent-red card the dark errorStrong (#991B1B) was
      // unreadable; the fix switches it to the light cancelled-text variant.
      expect(title.style?.color, AppColors.rideCancelledTextDark);
      expect(title.style?.color, isNot(AppColors.errorStrong));
    });
  });
}
