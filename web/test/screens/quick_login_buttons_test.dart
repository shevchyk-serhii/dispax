import 'package:dispax/modules/auth/widgets/quick_login_buttons.dart';
import 'package:dispax/modules/auth/widgets/test_credentials_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for [QuickLoginButtons] and [TestCredentialsCard].
///
/// Verifies that the SuperAdmin entry is present in both widgets — this guards
/// against accidental removal and confirms the button grid includes all 5 roles.
void main() {
  group('QuickLoginButtons', () {
    late List<String> capturedEmails;

    setUp(() {
      capturedEmails = [];
    });

    Widget buildSubject() => MaterialApp(
      home: Scaffold(body: QuickLoginButtons(onQuickLogin: capturedEmails.add)),
    );

    testWidgets('renders five role buttons', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text('Client'), findsOneWidget);
      expect(find.text('Driver'), findsOneWidget);
      expect(find.text('Secretary'), findsOneWidget);
      expect(find.text('Dispatcher'), findsOneWidget);
      expect(find.text('SuperAdmin'), findsOneWidget);
    });

    testWidgets('SuperAdmin button fires onQuickLogin with superadmin email', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.text('SuperAdmin'));
      await tester.pump();

      expect(capturedEmails, contains('superadmin@dispax.de'));
    });

    testWidgets('each button shows an icon', (tester) async {
      await tester.pumpWidget(buildSubject());

      // 5 buttons × 1 icon each = 5 icon widgets
      expect(find.byType(Icon), findsNWidgets(5));
    });

    testWidgets('SuperAdmin button uses admin_panel_settings icon', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byIcon(Icons.admin_panel_settings), findsOneWidget);
    });
  });

  group('TestCredentialsCard', () {
    late List<(String, String)> capturedCredentials;

    setUp(() {
      capturedCredentials = [];
    });

    Widget buildSubject() => MaterialApp(
      home: Scaffold(
        body: TestCredentialsCard(
          onCredentialTap: (email, password) =>
              capturedCredentials.add((email, password)),
        ),
      ),
    );

    testWidgets('renders SuperAdmin row', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.textContaining('SuperAdmin'), findsOneWidget);
      expect(find.text('superadmin@dispax.de'), findsOneWidget);
    });

    testWidgets(
      'tapping SuperAdmin row fires callback with correct credentials',
      (tester) async {
        await tester.pumpWidget(buildSubject());

        await tester.tap(find.text('superadmin@dispax.de'));
        await tester.pump();

        expect(capturedCredentials.length, greaterThanOrEqualTo(1));
        final last = capturedCredentials.last;
        expect(last.$1, 'superadmin@dispax.de');
        expect(last.$2, 'password123');
      },
    );

    testWidgets('renders all five role rows', (tester) async {
      await tester.pumpWidget(buildSubject());

      for (final email in [
        'client1@bmw.de',
        'driver1@dispax.de',
        'secretary@dispax.de',
        'dispatcher@dispax.de',
        'superadmin@dispax.de',
      ]) {
        expect(find.text(email), findsOneWidget, reason: 'Expected $email row');
      }
    });
  });
}
