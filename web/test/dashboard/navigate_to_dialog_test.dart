// Regression test for the "Navigate to" dialog being impossible to dismiss on
// iOS.
//
// The driver taps the "Navigate" action on a ride, which opens a "Navigate to"
// picker (pickup / drop-off) built with `showAdaptiveDialog` + `SimpleDialog`.
// On iOS `showAdaptiveDialog` renders a Cupertino-style dialog whose barrier is
// NOT dismissible by tapping outside (the `barrierDismissible` flag is ignored
// there), and the original dialog had no Cancel option — so the only way out
// was to pick an address, which launched Google Maps. The driver was trapped.
//
// The fix adds an explicit "Cancel" option that pops the dialog with `null`.
// This test drives the real `NavigationUtils.showNavigateToDialog` path and
// asserts the contract: tapping Cancel closes the dialog AND does not launch
// any navigation URL.
//
// Mutation check: remove the Cancel SimpleDialogOption from
// `NavigationUtils.showNavigateToDialog` -> the `finds the Cancel option` and
// `tapping Cancel closes the dialog` expectations go red.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/navigation_utils.dart';

import '../helpers/test_fixtures.dart';

class MockUrlLauncher extends Fake
    with MockPlatformInterfaceMixin
    implements UrlLauncherPlatform {
  String? lastLaunchedUrl;

  @override
  Future<bool> canLaunch(String url) async => true;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    lastLaunchedUrl = url;
    return true;
  }

  @override
  Future<void> closeWebView() async {}

  @override
  Future<bool> launch(
    String url, {
    required bool useSafariVC,
    required bool useWebView,
    required bool enableJavaScript,
    required bool enableDomStorage,
    required bool universalLinksOnly,
    required Map<String, String> headers,
    String? webOnlyWindowName,
  }) async {
    lastLaunchedUrl = url;
    return true;
  }
}

void main() {
  late MockUrlLauncher mockLauncher;

  setUp(() {
    mockLauncher = MockUrlLauncher();
    UrlLauncherPlatform.instance = mockLauncher;
  });

  // A button that opens the dialog, wrapped in a fully localized MaterialApp so
  // `AppLocalizations.of(context)!` resolves (without the delegates the helper
  // throws on the first `l10n.*` access).
  Widget buildHarness() {
    final ride = TestFixtures.ride(
      from: TestFixtures.location(address: 'Leopoldstraße 100, München'),
      to: TestFixtures.location(address: 'Flughafen München Terminal 1'),
    );
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                NavigationUtils.showNavigateToDialog(context, ride),
            child: const Text('Open'),
          ),
        ),
      ),
    );
  }

  Future<AppLocalizations> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(buildHarness());
    final l10n = AppLocalizations.of(tester.element(find.text('Open')))!;
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text(l10n.navigateTo), findsOneWidget);
    return l10n;
  }

  testWidgets(
    'opens the Navigate to dialog with both legs and a Cancel option',
    (tester) async {
      final l10n = await openDialog(tester);

      expect(find.text('Leopoldstraße 100, München'), findsOneWidget);
      expect(find.text('Flughafen München Terminal 1'), findsOneWidget);
      // The bug fix: an explicit Cancel option must be present.
      expect(find.text(l10n.cancel), findsOneWidget);
    },
  );

  testWidgets('tapping Cancel closes the dialog without launching navigation', (
    tester,
  ) async {
    final l10n = await openDialog(tester);

    await tester.tap(find.text(l10n.cancel));
    await tester.pumpAndSettle();

    // Dialog is gone...
    expect(find.text(l10n.navigateTo), findsNothing);
    // ...and Cancel must NOT open Google Maps.
    expect(mockLauncher.lastLaunchedUrl, isNull);
  });

  testWidgets('picking the pickup leg launches Google Maps navigation', (
    tester,
  ) async {
    final l10n = await openDialog(tester);

    await tester.tap(find.text('Leopoldstraße 100, München'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.navigateTo), findsNothing);
    expect(mockLauncher.lastLaunchedUrl, isNotNull);
    expect(mockLauncher.lastLaunchedUrl, contains('maps/dir'));
  });
}
