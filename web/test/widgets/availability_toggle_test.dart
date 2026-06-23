import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dispax/dashboard/driver/widgets/availability_toggle.dart';
import 'package:dispax/blocs/blocs.dart';
import 'package:dispax/l10n/app_localizations.dart';

// A minimal AuthBloc mock that returns default state so the toggle can render.
class _FakeAuthBloc extends Fake implements AuthBloc {
  @override
  AuthState get state => const AuthState();

  @override
  Stream<AuthState> get stream => Stream.value(const AuthState());

  @override
  void add(AuthEvent event) {}

  @override
  Future<void> close() async {}
}

void main() {
  group('AvailabilityToggle', () {
    testWidgets('renders Switch.adaptive (Switch) when bloc has no user', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: BlocProvider<AuthBloc>.value(
            value: _FakeAuthBloc(),
            child: const Scaffold(body: AvailabilityToggle()),
          ),
        ),
      );
      // initState calls _loadStatus, which reads user from bloc; user is null
      // so _loadStatus returns early. Widget renders with Switch.
      await tester.pump();

      // Switch.adaptive renders as Switch on non-iOS platforms in tests.
      expect(find.byType(Switch), findsOneWidget);
    });
  });
}
