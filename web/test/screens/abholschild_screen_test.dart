import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/screens/abholschild_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart'
    show wakelockPlusPlatformInstance;
import 'package:wakelock_plus_platform_interface/wakelock_plus_platform_interface.dart';

/// Records wakelock toggles so the sign board's "keep the screen awake only
/// while shown" behaviour can be asserted. `extends` (not `implements`) so it
/// passes the platform-interface token verification.
class _FakeWakelock extends WakelockPlusPlatformInterface {
  /// Synchronous view of the current state for assertions.
  bool isOn = false;
  final List<bool> toggles = [];

  @override
  Future<void> toggle({required bool enable}) async {
    isOn = enable;
    toggles.add(enable);
  }

  @override
  Future<bool> get enabled async => isOn;
}

void main() {
  late _FakeWakelock fakeWakelock;

  // Route the wakelock through a fake for every test — otherwise a test that
  // doesn't touch it still hits the real MethodChannel, and the leftover state
  // makes the wakelock-lifecycle test order-dependent.
  setUp(() {
    fakeWakelock = _FakeWakelock();
    // WakelockPlus captures its platform instance in a top-level var at first
    // use, so overriding WakelockPlusPlatformInterface.instance after that has no
    // effect. Assign the documented test override directly instead.
    wakelockPlusPlatformInstance = fakeWakelock;
  });

  Widget wrap() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: const AbholschildScreen(),
  );

  testWidgets('editor pre-fills the last shown text from SharedPreferences', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      AbholschildScreen.prefsKey: 'Herr Müller',
    });

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // The TextField is seeded with the persisted value.
    expect(find.widgetWithText(TextField, 'Herr Müller'), findsOneWidget);
  });

  testWidgets('empty text does not open the board and persists nothing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    // Tap "Show" with an empty field.
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    // Still on the editor (title visible), no full-screen board pushed.
    expect(find.text('Pickup Sign'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(AbholschildScreen.prefsKey), isNull);
  });

  testWidgets(
    'entering text and tapping Show persists it and renders the white sign board',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Familie Schmidt');
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // The board renders the entered text, auto-scaled inside a FittedBox
      // (distinct from the editor's TextField, which also holds the text under
      // the pushed route) on a white Scaffold — independent of the app theme.
      final boardText = find.descendant(
        of: find.byType(FittedBox),
        matching: find.text('Familie Schmidt'),
      );
      expect(boardText, findsOneWidget);
      final scaffold = tester.widget<Scaffold>(
        find.ancestor(of: boardText, matching: find.byType(Scaffold)).first,
      );
      expect(scaffold.backgroundColor, Colors.white);

      // The text is persisted for next time.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AbholschildScreen.prefsKey), 'Familie Schmidt');

      // Tapping the board pops back to the editor; the board (FittedBox) is gone
      // and the editor keeps the entered text in its field.
      await tester.tap(boardText);
      await tester.pumpAndSettle();
      expect(find.text('Pickup Sign'), findsOneWidget);
      expect(find.byType(FittedBox), findsNothing);
      expect(find.widgetWithText(TextField, 'Familie Schmidt'), findsOneWidget);
    },
  );

  testWidgets('the sign text is scaled up to fill the board width', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    // A fixed, wide viewport so the expected width is deterministic.
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Müller');
    await tester.tap(find.text('Show'));
    await tester.pumpAndSettle();

    // The FittedBox must fill the available board area (tight constraints), so
    // it scales the text up. A plain Center passes loose constraints and the
    // FittedBox collapses to the text's natural ~85px width — the "tiny text"
    // bug. Measuring the FittedBox box (not the Text, whose getSize is the
    // pre-Transform natural size) is what encodes "fills the area": the earlier
    // tests only checked the text existed, so the bug rendered green.
    final fittedBox = tester.getSize(find.byType(FittedBox));
    // Board width is the 800px viewport minus the 24px padding on each side.
    expect(fittedBox.width, greaterThan(800 * 0.7));

    // Close the board so its wakelock disable() doesn't bleed into the next
    // test's fresh fake (the board's dispose runs during the next pumpWidget).
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'keeps the screen awake only while the board is shown (enable on show, disable on pop)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Editor is up — wakelock must NOT be engaged yet (no leak into the app).
      expect(fakeWakelock.isOn, isFalse);

      await tester.enterText(find.byType(TextField), 'Gate B12');
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();

      // Board shown → screen kept awake.
      expect(fakeWakelock.isOn, isTrue);

      // Back to the editor → wakelock released (bound exactly to the board route).
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(fakeWakelock.isOn, isFalse);

      // Exactly one enable followed by one disable — no leak, no double-toggle.
      expect(fakeWakelock.toggles, [true, false]);
    },
  );
}
