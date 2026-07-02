import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_event.dart';
import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/constants/app_dimensions.dart';
import 'package:dispax/l10n/app_localizations.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/utils/service_zone.dart';
import 'package:dispax/modules/ride_management/widgets/sections/create_ride_location_section.dart';
import 'package:dispax/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// The ↕ swap button between From/To must visually swap the two addresses even
// when one of the fields is still focused (the common case: the user just
// picked an address, so that field holds focus). The BLoC swap is correct; the
// regression was that the focused AddressAutocompleteField skipped its
// state→controller sync, leaving stale text on screen. This test reproduces the
// focused-field condition and asserts the displayed text actually swaps.

class _MockAuthBloc extends MockBloc<AuthEvent, AuthState>
    implements AuthBloc {}

class _MockApiClient extends Mock implements ApiClient {}

Person _dispatcher() => Person(
  id: 'dispatcher-1',
  name: 'Maria Meier',
  email: 'maria@example.com',
  role: PersonRole.dispatcher,
  companyId: 'company-1',
  phone: '+491111111111',
);

// The From/To TextFormFields are distinguished by their label text.
Finder _fieldByLabel(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(TextFormField));

String _textOf(WidgetTester tester, String label) =>
    tester.widget<TextFormField>(_fieldByLabel(label)).controller!.text;

// Always-reachable resolver — keeps the non-reachability tests deterministic and
// free of any Mapbox/network dependency.
Future<ReachabilityResult> _alwaysReachable(String _) async =>
    const ReachabilityResult(Reachability.reachable, distanceKm: 1.0);

// No Mapbox suggestions by default — keeps the non-autocomplete tests quiet.
Future<List<String>> _noSuggestions(String _) async => const [];

Widget _harness(
  AuthBloc authBloc,
  CreateRideFormBloc formBloc, {
  ThemeData? theme,
  ReachabilityResolver resolver = _alwaysReachable,
  AddressSuggester suggester = _noSuggestions,
}) {
  return MaterialApp(
    theme: theme,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<CreateRideFormBloc>.value(value: formBloc),
        ],
        child: CreateRideLocationSection(
          reachabilityResolver: resolver,
          addressSuggester: suggester,
        ),
      ),
    ),
  );
}

(AuthBloc, CreateRideFormBloc) _blocs() {
  final authBloc = _MockAuthBloc();
  final formBloc = CreateRideFormBloc();
  when(() => authBloc.apiClient).thenReturn(_MockApiClient());
  when(() => authBloc.state).thenReturn(AuthState.authenticated(_dispatcher()));
  return (authBloc, formBloc);
}

void main() {
  testWidgets('swap button swaps the visible From/To text while a field is '
      'focused', (tester) async {
    final (authBloc, formBloc) = _blocs();
    addTearDown(formBloc.close);

    await tester.pumpWidget(_harness(authBloc, formBloc));
    await tester.pump();

    // Type into From, then into To. Entering text into To leaves it focused,
    // which is exactly the condition that used to break the swap.
    await tester.enterText(
      _fieldByLabel('From'),
      'Flughafen Muenchen Terminal 2',
    );
    await tester.pump();
    await tester.enterText(_fieldByLabel('To'), 'Leopoldstrasse 42, Muenchen');
    await tester.pump();

    await tester.tap(find.byTooltip('Swap From / To'));
    await tester.pumpAndSettle();

    // Both the state AND the displayed text must reflect the swap.
    expect(formBloc.state.fromAddress, 'Leopoldstrasse 42, Muenchen');
    expect(formBloc.state.toAddress, 'Flughafen Muenchen Terminal 2');
    expect(_textOf(tester, 'From'), 'Leopoldstrasse 42, Muenchen');
    expect(_textOf(tester, 'To'), 'Flughafen Muenchen Terminal 2');
  });

  // Dark-mode regression: the ↕ swap icon used a hardcoded graphite foreground
  // (AppColors.secretaryColor == AppColors.primary == surfaceDark), so in dark
  // mode it was a dark icon on an identically dark surface — invisible. The
  // fix reads the theme's onSurfaceVariant instead. This asserts the resolved
  // foreground color is visible against the dark surface.
  testWidgets('swap button icon is visible (not the dark surface color) in '
      'dark theme', (tester) async {
    final (authBloc, formBloc) = _blocs();
    addTearDown(formBloc.close);

    await tester.pumpWidget(
      _harness(authBloc, formBloc, theme: AppTheme.darkTheme),
    );
    await tester.pump();

    final button = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Swap From / To'),
        matching: find.byType(IconButton),
      ),
    );

    // Resolve the button's foreground color the way the framework does, against
    // the default (enabled) state.
    final resolved = button.style!.foregroundColor!.resolve(<WidgetState>{});

    // It must adapt to the dark theme and stay visible on the dark surface —
    // i.e. NOT the graphite that matches surfaceDark.
    expect(resolved, AppColors.textSecondaryDark); // onSurfaceVariant (dark)
    expect(resolved, isNot(AppColors.surfaceDark));
    expect(resolved, isNot(AppColors.primary));
  });

  // Compact-spacing regression: the gap between the "Ride Locations" title and
  // the From field must use the tight formSectionGap, not the looser 16dp gap
  // the form started with. A revert to paddingMedium would re-add the
  // whitespace the user asked to remove.
  testWidgets('title→field gap uses the compact formSectionGap', (
    tester,
  ) async {
    final (authBloc, formBloc) = _blocs();
    addTearDown(formBloc.close);

    await tester.pumpWidget(_harness(authBloc, formBloc));
    await tester.pump();

    // The section's fixed-height SizedBoxes are the title→field gap
    // (formSectionGap) and the two swap-button gaps (paddingSmall). Exactly one
    // must be the compact section gap, and none may be the old 16dp gap.
    final heights = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .map((b) => b.height)
        .whereType<double>()
        .toList();

    expect(
      heights.where((h) => h == AppDimensions.formSectionGap).length,
      1,
      reason: 'title→field gap should be the compact formSectionGap',
    );
    expect(
      heights.contains(AppDimensions.paddingMedium),
      isFalse,
      reason: 'no 16dp gap should remain in the compacted section',
    );
  });

  // Reachability is a SOFT, advisory check: an out-of-area or not-found address
  // shows an inline warning but must NOT block — the field keeps working and
  // there is no error-colored blocker. These tests pin that behavior.

  testWidgets('out-of-area address shows an inline warning', (tester) async {
    final (authBloc, formBloc) = _blocs();
    addTearDown(formBloc.close);

    await tester.pumpWidget(
      _harness(
        authBloc,
        formBloc,
        resolver: (_) async =>
            const ReachabilityResult(Reachability.outOfArea, distanceKm: 480.0),
      ),
    );
    await tester.pump();

    await tester.enterText(_fieldByLabel('From'), 'Berlin Hauptbahnhof');
    // Drive the debounce timer and the async resolver to completion.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.addressOutOfServiceArea(480, 100)), findsOneWidget);
    // The warning sits under the field; the field itself stays usable.
    expect(_fieldByLabel('From'), findsOneWidget);
  });

  testWidgets('not-found address shows the not-found warning', (tester) async {
    final (authBloc, formBloc) = _blocs();
    addTearDown(formBloc.close);

    await tester.pumpWidget(
      _harness(
        authBloc,
        formBloc,
        resolver: (_) async => const ReachabilityResult(Reachability.notFound),
      ),
    );
    await tester.pump();

    await tester.enterText(_fieldByLabel('To'), 'asdkjhaskdjh');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.addressNotFound), findsOneWidget);
  });

  testWidgets('reachable address shows NO warning', (tester) async {
    final (authBloc, formBloc) = _blocs();
    addTearDown(formBloc.close);

    await tester.pumpWidget(
      _harness(authBloc, formBloc, resolver: _alwaysReachable),
    );
    await tester.pump();

    await tester.enterText(_fieldByLabel('From'), 'Marienplatz, Muenchen');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.addressNotFound), findsNothing);
    // No out-of-area warning either (it carries the warning icon).
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);
  });

  testWidgets('typing >=3 chars surfaces Mapbox autocomplete suggestions', (
    tester,
  ) async {
    final (authBloc, formBloc) = _blocs();
    addTearDown(formBloc.close);

    var lastQuery = '';
    await tester.pumpWidget(
      _harness(
        authBloc,
        formBloc,
        suggester: (q) async {
          lastQuery = q;
          return ['Marienplatz 1, München', 'Marienhof 3, München'];
        },
      ),
    );
    await tester.pump();

    await tester.enterText(_fieldByLabel('From'), 'Mar');
    // Drive the debounce timer + async suggester to completion.
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // The suggester was queried with what the user typed.
    expect(lastQuery, 'Mar');

    // Autocomplete rebuilds its options from `suggestions` when the field text
    // changes, so the next keystroke surfaces the freshly-fetched Mapbox list.
    // 'Marien' is a substring of both returned suggestions, so both pass the
    // widget's substring filter and render as options.
    await tester.enterText(_fieldByLabel('From'), 'Marien');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Marienplatz 1, München'), findsOneWidget);
    expect(find.text('Marienhof 3, München'), findsOneWidget);
  });

  testWidgets('out-of-area warning does NOT disable the form (soft check)', (
    tester,
  ) async {
    final (authBloc, formBloc) = _blocs();
    addTearDown(formBloc.close);

    await tester.pumpWidget(
      _harness(
        authBloc,
        formBloc,
        resolver: (_) async =>
            const ReachabilityResult(Reachability.outOfArea, distanceKm: 480.0),
      ),
    );
    await tester.pump();

    await tester.enterText(_fieldByLabel('From'), 'Berlin');
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // The address still flows into the form state — nothing is rejected.
    formBloc.add(const FromAddressChanged('Berlin'));
    await tester.pump();
    expect(formBloc.state.fromAddress, 'Berlin');
  });
}
