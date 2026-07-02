// RidePersonCard must render the person via AvatarCircle (photo when set,
// initials fallback) — not a hardcoded role icon — and must not depend on an
// ambient AuthBloc provider (it is shown inside a pushed RideDetailsScreen route
// that can sit outside the provider tree; the apiClient is passed in explicitly).
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/widgets/avatar_circle.dart';
import 'package:dispax/modules/ride_management/widgets/ride_person_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders the person via AvatarCircle (no ambient AuthBloc needed)', (
    tester,
  ) async {
    // A bare ApiClient with a stub HTTP client — no BlocProvider anywhere, mirroring
    // the pushed-route scope where context.read<AuthBloc>() would throw.
    final apiClient = ApiClient(
      client: MockClient((_) async => http.Response('', 404)),
      baseUrl: 'http://localhost:8080/api',
    );

    await tester.pumpWidget(
      _wrap(
        RidePersonCard(
          person: Person(
            id: 'client-1',
            name: 'Frau Meier',
            email: '',
            role: PersonRole.client,
          ),
          apiClient: apiClient,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(AvatarCircle), findsOneWidget);
    // No ProviderNotFoundException (or any framework error) leaked.
    expect(tester.takeException(), isNull);
  });

  testWidgets('fetches the photo bytes when the person has an avatar', (
    tester,
  ) async {
    var avatarRequested = false;
    final apiClient = ApiClient(
      client: MockClient((request) async {
        if (request.url.path.contains('/avatar')) {
          avatarRequested = true;
          return http.Response.bytes([0xFF, 0xD8, 0xFF], 200);
        }
        return http.Response('', 404);
      }),
      baseUrl: 'http://localhost:8080/api',
    );
    apiClient.setAuthToken('t');

    await tester.pumpWidget(
      _wrap(
        RidePersonCard(
          person: Person(
            id: 'driver-1',
            name: 'Hans Weber',
            email: '',
            role: PersonRole.driver,
            hasAvatar: true,
          ),
          apiClient: apiClient,
          isDriver: true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(AvatarCircle), findsOneWidget);
    expect(avatarRequested, isTrue);
    expect(tester.takeException(), isNull);
  });
}
