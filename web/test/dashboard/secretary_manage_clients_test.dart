// The secretary front desk exposes client management via the "Active clients"
// stat tile: tapping it pushes the ClientListPanel (where a client can be
// created). Before this, the panel was unreachable from any live navigation.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/ride/ride_bloc.dart';
import 'package:dispax/blocs/ride/ride_event.dart';
import 'package:dispax/blocs/ride/ride_state.dart';
import 'package:dispax/dashboard/secretary/secretary_dashboard.dart';
import 'package:dispax/dashboard/secretary/widgets/client_list_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class _FakeRideEvent extends Fake implements RideEvent {}

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockRideBloc extends MockBloc<RideEvent, RideState>
    implements RideBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _secretary() => Person(
  id: 'sec-1',
  name: 'Secretary Sara',
  email: 'sara@example.com',
  role: PersonRole.secretary,
  companyId: 'company-1',
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeRideEvent()));

  late _MockAuthBloc authBloc;
  late _MockRideBloc rideBloc;
  late _MockApiClient apiClient;

  setUp(() {
    authBloc = _MockAuthBloc();
    rideBloc = _MockRideBloc();
    apiClient = _MockApiClient();

    when(() => authBloc.apiClient).thenReturn(apiClient);
    when(
      () => authBloc.state,
    ).thenReturn(AuthState.authenticated(_secretary()));
    // Client list / template / ride-template GETs → empty list.
    when(
      () => apiClient.get(any()),
    ).thenAnswer((_) async => http.Response('[]', 200));

    when(() => rideBloc.state).thenReturn(RideState.loaded(const []));
    when(() => rideBloc.add(any())).thenAnswer((_) {});
  });

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<RideBloc>.value(value: rideBloc),
      ],
      child: const SecretaryDashboard(),
    ),
  );

  testWidgets(
    'tapping the "Active clients" stat tile opens the client list panel',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The front desk Home tab is shown by default; find the Active clients tile.
      expect(find.text('Active clients'), findsOneWidget);
      expect(find.byType(ClientListPanel), findsNothing);

      await tester.tap(find.text('Active clients'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The pushed route renders ClientListPanel with its create-client FAB.
      expect(find.byType(ClientListPanel), findsOneWidget);
      expect(find.byIcon(Icons.person_add), findsOneWidget);
    },
  );

  testWidgets(
    'only the "Active clients" tile is interactive (chevron affordance); '
    'the other stat tiles are not',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(host());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // The interactive tile carries a chevron and is wrapped in an InkWell.
      final chevron = find.byIcon(Icons.chevron_right);
      expect(
        chevron,
        findsOneWidget,
        reason: 'the "Active clients" tile must show a chevron affordance',
      );
      expect(
        find.ancestor(of: chevron, matching: find.byType(InkWell)),
        findsOneWidget,
        reason: 'the chevron tile must be tappable (InkWell)',
      );

      // The sibling "Booked today" tile is a plain, non-interactive tile: its
      // value text must not sit inside an InkWell.
      expect(
        find.ancestor(
          of: find.text('Booked today'),
          matching: find.byType(InkWell),
        ),
        findsNothing,
        reason: 'non-client stat tiles must remain non-interactive',
      );
    },
  );
}
