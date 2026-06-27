import 'package:bloc_test/bloc_test.dart';
import 'package:dispax/blocs/auth/auth_bloc.dart';
import 'package:dispax/blocs/auth/auth_event.dart';
import 'package:dispax/blocs/auth/auth_state.dart';
import 'package:dispax/blocs/create_ride_form/create_ride_form_bloc.dart';
import 'package:dispax/constants/app_colors.dart';
import 'package:dispax/constants/app_dimensions.dart';
import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
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

void main() {
  testWidgets('swap button swaps the visible From/To text while a field is '
      'focused', (tester) async {
    final authBloc = _MockAuthBloc();
    final formBloc = CreateRideFormBloc();
    when(() => authBloc.apiClient).thenReturn(_MockApiClient());
    when(
      () => authBloc.state,
    ).thenReturn(AuthState.authenticated(_dispatcher()));
    addTearDown(formBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<CreateRideFormBloc>.value(value: formBloc),
            ],
            child: const CreateRideLocationSection(),
          ),
        ),
      ),
    );
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
    final authBloc = _MockAuthBloc();
    final formBloc = CreateRideFormBloc();
    when(() => authBloc.apiClient).thenReturn(_MockApiClient());
    when(
      () => authBloc.state,
    ).thenReturn(AuthState.authenticated(_dispatcher()));
    addTearDown(formBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<CreateRideFormBloc>.value(value: formBloc),
            ],
            child: const CreateRideLocationSection(),
          ),
        ),
      ),
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
    final authBloc = _MockAuthBloc();
    final formBloc = CreateRideFormBloc();
    when(() => authBloc.apiClient).thenReturn(_MockApiClient());
    when(
      () => authBloc.state,
    ).thenReturn(AuthState.authenticated(_dispatcher()));
    addTearDown(formBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: authBloc),
              BlocProvider<CreateRideFormBloc>.value(value: formBloc),
            ],
            child: const CreateRideLocationSection(),
          ),
        ),
      ),
    );
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
}
