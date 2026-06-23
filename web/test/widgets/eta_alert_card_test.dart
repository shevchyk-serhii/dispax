import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/dashboard/dispatcher/widgets/eta_alert_card.dart';
import 'package:dispax/constants/lucide_compat.dart';
import 'package:dispax/constants/app_colors.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  // Use darkTheme + ThemeMode.dark so that Theme.of(context).brightness
  // actually returns Brightness.dark inside the widget tree.
  const delegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];
  const supportedLocales = [Locale('en')];
  if (brightness == Brightness.dark) {
    return MaterialApp(
      localizationsDelegates: delegates,
      supportedLocales: supportedLocales,
      locale: const Locale('en'),
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
    locale: const Locale('en'),
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
}
