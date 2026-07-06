import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/widgets/copy_icon_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget mount(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('tapping copies the value and shows a "copied" SnackBar', (
    tester,
  ) async {
    // Capture what CopyIconButton writes to the clipboard via the platform channel.
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      mount(const CopyIconButton(value: 'Munich Airport', label: 'Pickup')),
    );

    expect(find.byIcon(Icons.copy), findsOneWidget);
    await tester.tap(find.byIcon(Icons.copy));
    await tester.pump(); // let the SnackBar appear

    // The exact value reached the clipboard...
    expect(copied, ['Munich Airport']);
    // ...and a confirmation toast naming the field is shown.
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.copiedToClipboard('Pickup')), findsOneWidget);
  });

  testWidgets('renders nothing when the value is blank', (tester) async {
    await tester.pumpWidget(
      mount(const CopyIconButton(value: '   ', label: 'Flight')),
    );
    expect(find.byIcon(Icons.copy), findsNothing);
  });
}
