// Regression: the add-client FloatingActionButton on the Manage Clients panel
// hardcoded backgroundColor: AppColors.secretaryColor (graphite 0xFF18181B).
// On the dark theme's near-black scaffold the button was invisible, so users
// could not find the add-client entry point. The FAB must resolve its color
// from the theme (colorScheme.primary) so it stays legible in both modes.

import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/client/client_bloc.dart';
import 'package:dispax/blocs/client/client_event.dart';
import 'package:dispax/blocs/client/client_state.dart';
import 'package:dispax/dashboard/secretary/widgets/client_list_panel.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockClientBloc extends MockBloc<ClientEvent, ClientState>
    implements ClientBloc {}

class _FakeClientEvent extends Fake implements ClientEvent {}

void main() {
  setUpAll(() => registerFallbackValue(_FakeClientEvent()));

  late _MockClientBloc clientBloc;

  setUp(() {
    clientBloc = _MockClientBloc();
    when(() => clientBloc.state).thenReturn(ClientState.loaded(const []));
    when(() => clientBloc.add(any())).thenAnswer((_) {});
  });

  Widget host(ThemeData theme) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    locale: const Locale('en'),
    theme: theme,
    home: BlocProvider<ClientBloc>.value(
      value: clientBloc,
      child: const ClientListPanel(),
    ),
  );

  Color? fabFillColor(WidgetTester tester) {
    final materials = tester.widgetList<Material>(
      find.descendant(
        of: find.byType(FloatingActionButton),
        matching: find.byType(Material),
      ),
    );
    return materials.firstWhere((m) => m.color != null).color;
  }

  testWidgets('add-client FAB uses the theme primary color in dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(host(AppTheme.darkTheme));
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);

    final fabColor = fabFillColor(tester);
    final context = tester.element(find.byType(FloatingActionButton));
    final expected = Theme.of(context).colorScheme.primary;

    expect(
      fabColor,
      expected,
      reason: 'the FAB must take the dark theme primary (light) color',
    );
    // Guard against the regression returning: the hardcoded graphite
    // secretaryColor must not be painted on the dark background.
    expect(fabColor, isNot(const Color(0xFF18181B)));
  });

  testWidgets('add-client FAB uses the theme primary color in light mode', (
    tester,
  ) async {
    await tester.pumpWidget(host(AppTheme.theme));
    await tester.pumpAndSettle();

    final fabColor = fabFillColor(tester);
    final context = tester.element(find.byType(FloatingActionButton));
    final expected = Theme.of(context).colorScheme.primary;

    expect(fabColor, expected);
  });
}
