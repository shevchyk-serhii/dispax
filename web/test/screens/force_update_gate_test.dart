import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/screens/force_update_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import '../helpers/mocks.dart';

void main() {
  late MockApiClient apiClient;

  setUp(() {
    apiClient = MockApiClient();
  });

  // A sentinel child so we can assert the normal app IS or ISN'T rendered.
  const childKey = Key('app-behind-the-gate');
  Widget buildGate() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ForceUpdateGate(
      apiClient: apiClient,
      child: const Scaffold(body: Text('APP', key: childKey)),
    ),
  );

  http.Response versionJson(int minClientVersion) => http.Response(
    '{"version":"0.1.0","commit":"a1b2c3d","branch":"master",'
    '"buildTime":"2026-06-29T06:23:24Z","apiVersion":$minClientVersion,'
    '"minClientVersion":$minClientVersion}',
    200,
  );

  testWidgets('blocks when the client is older than minClientVersion', (
    tester,
  ) async {
    // kClientApiVersion is 1; require 2 → outdated.
    when(
      () => apiClient.get('/version'),
    ).thenAnswer((_) async => versionJson(2));

    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    expect(find.byKey(childKey), findsNothing);
    expect(find.text('Update required'), findsWidgets);
    expect(find.text('Update now'), findsOneWidget);
  });

  testWidgets('lets the app through when the client meets the minimum', (
    tester,
  ) async {
    when(
      () => apiClient.get('/version'),
    ).thenAnswer((_) async => versionJson(1));

    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    expect(find.byKey(childKey), findsOneWidget);
    expect(find.text('Update required'), findsNothing);
  });

  testWidgets('fail-open: lets the app through when the version check fails', (
    tester,
  ) async {
    when(
      () => apiClient.get('/version'),
    ).thenAnswer((_) async => http.Response('{"error":"boom"}', 500));

    await tester.pumpWidget(buildGate());
    await tester.pumpAndSettle();

    expect(find.byKey(childKey), findsOneWidget);
    expect(find.text('Update required'), findsNothing);
  });
}
