import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/schedule_management/models/calendar_share.dart';
import 'package:dispax/modules/schedule_management/services/calendar_share_service.dart';
import 'package:dispax/screens/calendar_sharing_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockCalendarShareService extends Mock implements CalendarShareService {}

void main() {
  late _MockCalendarShareService service;

  final invite = CalendarShareInvite(
    id: 'invite-1',
    code: 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-Abc',
    createdAt: DateTime.utc(2026, 7, 1),
    expiresAt: DateTime.utc(2026, 7, 8),
  );

  final grantedGrant = CalendarShareGrant(
    id: 'grant-out-1',
    grantorName: 'Me Myself',
    grantorCompanyName: 'My GmbH',
    granteeName: 'Boris Partner',
    granteeCompanyName: 'Partner GmbH',
    createdAt: DateTime.utc(2026, 7, 1),
  );

  final sharedWithMeGrant = CalendarShareGrant(
    id: 'grant-in-1',
    grantorName: 'Anna External',
    grantorCompanyName: 'External GmbH',
    granteeName: 'Me Myself',
    granteeCompanyName: 'My GmbH',
    createdAt: DateTime.utc(2026, 7, 1),
  );

  setUp(() {
    service = _MockCalendarShareService();
    when(() => service.getMyInvites()).thenAnswer((_) async => [invite]);
    when(() => service.getGranted()).thenAnswer((_) async => [grantedGrant]);
    when(
      () => service.getSharedWithMe(),
    ).thenAnswer((_) async => [sharedWithMeGrant]);
    when(() => service.dispose()).thenReturn(null);
  });

  Widget wrap() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: CalendarSharingScreen(service: service),
  );

  group('CalendarSharingScreen', () {
    testWidgets('renders invites, outgoing grants and shared-with-me', (
      tester,
    ) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Boris Partner'), findsOneWidget);
      expect(find.text('Anna External'), findsOneWidget);
      expect(find.textContaining('AbCdEfGh'), findsOneWidget);
    });

    testWidgets('revoking an outgoing grant removes it optimistically', (
      tester,
    ) async {
      when(() => service.revokeGranted('grant-out-1')).thenAnswer((_) async {});
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // The revoke button of the outgoing-grants card is the last 'Revoke'.
      await tester.tap(find.text('Revoke').last);
      await tester.pump();

      expect(find.text('Boris Partner'), findsNothing);
      verify(() => service.revokeGranted('grant-out-1')).called(1);
    });

    testWidgets('failed revoke rolls the row back and shows an error', (
      tester,
    ) async {
      when(
        () => service.revokeGranted('grant-out-1'),
      ).thenThrow(ApiException('boom'));
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Revoke').last);
      await tester.pumpAndSettle();

      expect(find.text('Boris Partner'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('redeeming a code adds the calendar to shared-with-me', (
      tester,
    ) async {
      final newGrant = CalendarShareGrant(
        id: 'grant-in-2',
        grantorName: 'Clara New',
        grantorCompanyName: 'New GmbH',
        granteeName: 'Me Myself',
        granteeCompanyName: 'My GmbH',
        createdAt: DateTime.utc(2026, 7, 2),
      );
      when(() => service.redeem(any())).thenAnswer((_) async => newGrant);

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Enter code'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-Abc',
      );
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      expect(find.text('Clara New'), findsOneWidget);
      verify(
        () => service.redeem('AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-Abc'),
      ).called(1);
    });

    testWidgets('unlinking a shared-with-me calendar removes it', (
      tester,
    ) async {
      when(
        () => service.unlinkSharedWithMe('grant-in-1'),
      ).thenAnswer((_) async {});
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unlink'));
      await tester.pump();

      expect(find.text('Anna External'), findsNothing);
      verify(() => service.unlinkSharedWithMe('grant-in-1')).called(1);
    });
  });

  group('extractCode', () {
    const code = 'AbCdEfGhIjKlMnOpQrStUvWxYz0123456789_-Abc';

    test('passes a raw code through', () {
      expect(CalendarSharingScreen.extractCode(code), code);
    });

    test('extracts the code from a pasted link', () {
      expect(
        CalendarSharingScreen.extractCode(
          'https://dispax.app/calendar-share/$code',
        ),
        code,
      );
      expect(
        CalendarSharingScreen.extractCode('dispax://calendar-share/$code'),
        code,
      );
    });

    test('trims surrounding whitespace', () {
      expect(CalendarSharingScreen.extractCode('  $code\n'), code);
    });
  });
}
