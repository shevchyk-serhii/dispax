// Regression: the secretary client-LIST edit dialog had no VIP toggle (only the
// client-DETAIL dialog did), and it never sent isVip in UpdateUserRequest — so
// VIP status could not be changed from the list. The dialog must now expose a
// VIP switch and include isVip in the dispatched ClientUpdateRequested.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/client/client_bloc.dart';
import 'package:dispax/blocs/client/client_event.dart';
import 'package:dispax/blocs/client/client_state.dart';
import 'package:dispax/dashboard/secretary/widgets/client_list_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClientBloc extends MockBloc<ClientEvent, ClientState>
    implements ClientBloc {}

class _FakeClientEvent extends Fake implements ClientEvent {}

Person _vipClient() => Person(
  id: 'client-1',
  name: 'Bruno Aldi',
  email: 'bruno@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
  phone: '+491234567890',
  isVip: true,
);

Person _plainClient() => Person(
  id: 'client-2',
  name: 'Anna Klein',
  email: 'anna@example.com',
  role: PersonRole.client,
  companyId: 'company-1',
  phone: '+491234567891',
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeClientEvent()));

  late _MockClientBloc clientBloc;

  setUp(() {
    clientBloc = _MockClientBloc();
    when(() => clientBloc.state).thenReturn(ClientState.loaded([_vipClient()]));
    when(() => clientBloc.add(any())).thenAnswer((_) {});
  });

  Widget host() => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locale: const Locale('en'),
    home: Scaffold(
      body: BlocProvider<ClientBloc>.value(
        value: clientBloc,
        child: const ClientListPanel(),
      ),
    ),
  );

  testWidgets('list edit dialog exposes a VIP toggle and sends isVip on save', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    // Open the per-client popup menu and pick "Edit".
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.editAction).last);
    await tester.pumpAndSettle();

    // The VIP switch is present and starts ON (the client is VIP).
    expect(find.byType(SwitchListTile), findsOneWidget);
    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.value, isTrue);

    // Toggle VIP off and save.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, l10n.save));
    await tester.pumpAndSettle();

    final captured = verify(
      () => clientBloc.add(captureAny()),
    ).captured.whereType<ClientUpdateRequested>().toList();

    expect(captured, hasLength(1));
    expect(captured.single.clientId, 'client-1');
    expect(
      captured.single.request.isVip,
      isFalse,
      reason: 'the VIP toggle change must reach the update request',
    );
  });

  // The panel uses automaticallyImplyLeading: true so that, when pushed as its
  // own route (e.g. from the secretary front desk / dispatcher More menu), the
  // AppBar gets a back button. When it is the root content of a route there is
  // nothing to pop, so no back button is shown.
  testWidgets('AppBar shows a back button when pushed as its own route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // A home screen with a button that pushes the panel onto the navigator.
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BlocProvider<ClientBloc>.value(
                    value: clientBloc,
                    child: const ClientListPanel(),
                  ),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // A back button (BackButton or the close icon) must be present on the route.
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('AppBar shows no back button when it is the root content', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(host());
    await tester.pumpAndSettle();

    // host() places the panel as the root route, so there is nothing to pop.
    expect(find.byType(BackButton), findsNothing);
  });

  // Regression: the client name (the ListTile title) used AppStyles.titleSmall,
  // whose hardcoded color is the light-theme AppColors.textPrimary (near-black).
  // On a dark Card surface that text was black-on-dark and therefore invisible.
  // The name must now resolve to the theme's onSurface color so it is readable
  // in dark mode.
  testWidgets('client name uses theme onSurface color (visible in dark mode)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(
      () => clientBloc.state,
    ).thenReturn(ClientState.loaded([_plainClient()]));

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        locale: const Locale('en'),
        theme: AppTheme.darkTheme,
        home: BlocProvider<ClientBloc>.value(
          value: clientBloc,
          child: const ClientListPanel(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final nameWidget = tester.widget<Text>(find.text('Anna Klein'));
    final context = tester.element(find.text('Anna Klein'));
    final expected = Theme.of(context).colorScheme.onSurface;

    expect(
      nameWidget.style?.color,
      expected,
      reason: 'the client name must use the dark theme onSurface color',
    );
    // Guard against the regression returning: the hardcoded light textPrimary
    // (what AppStyles.titleSmall carries by default) must not be used.
    expect(nameWidget.style?.color, isNot(const Color(0xFF18181B)));
  });
}
