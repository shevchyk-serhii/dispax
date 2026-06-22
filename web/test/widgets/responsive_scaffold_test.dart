import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/widgets/common/responsive_scaffold.dart';
import 'package:dispax/constants/app_dimensions.dart';

const _destinations = [
  NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
  NavigationDestination(icon: Icon(Icons.list), label: 'Rides'),
  NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
];

Widget _buildScaffold({
  required double width,
  required int selectedIndex,
  ValueChanged<int>? onSelected,
}) {
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: SizedBox(
        width: width,
        height: 800,
        child: ResponsiveScaffold(
          destinations: _destinations,
          selectedIndex: selectedIndex,
          onDestinationSelected: onSelected ?? (_) {},
          body: const Text('Body Content'),
        ),
      ),
    ),
  );
}

// Helper that sets the physical viewport and tears it down after the test.
Future<void> _setViewport(
  WidgetTester tester,
  double width,
  double height,
) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
}

void _resetViewport(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void main() {
  group('ResponsiveScaffold — layout branch selection', () {
    testWidgets('shows BottomNavigationBar at width 700 (< breakpoint)', (
      tester,
    ) async {
      await _setViewport(tester, 700, 800);
      addTearDown(() => _resetViewport(tester));

      await tester.pumpWidget(_buildScaffold(width: 700, selectedIndex: 0));
      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('shows NavigationRail at width 1000 (>= breakpoint)', (
      tester,
    ) async {
      await _setViewport(tester, 1000, 800);
      addTearDown(() => _resetViewport(tester));

      await tester.pumpWidget(_buildScaffold(width: 1000, selectedIndex: 0));
      await tester.pump();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    // Boundary: exactly at breakpointDesktop (800) → desktop layout.
    testWidgets('shows NavigationRail at EXACTLY breakpointDesktop (800 px)', (
      tester,
    ) async {
      const bp = AppDimensions.breakpointDesktop; // 800
      await _setViewport(tester, bp, 800);
      addTearDown(() => _resetViewport(tester));

      await tester.pumpWidget(_buildScaffold(width: bp, selectedIndex: 0));
      await tester.pump();

      expect(
        find.byType(NavigationRail),
        findsOneWidget,
        reason: 'width == breakpointDesktop should use desktop layout',
      );
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    // One pixel below breakpoint → mobile layout.
    testWidgets('shows BottomNavigationBar at 799 px (one below breakpoint)', (
      tester,
    ) async {
      await _setViewport(tester, 799, 800);
      addTearDown(() => _resetViewport(tester));

      await tester.pumpWidget(_buildScaffold(width: 799, selectedIndex: 0));
      await tester.pump();

      expect(
        find.byType(BottomNavigationBar),
        findsOneWidget,
        reason: 'width < breakpointDesktop should use mobile layout',
      );
      expect(find.byType(NavigationRail), findsNothing);
    });
  });

  group('ResponsiveScaffold — ConstrainedBox on desktop', () {
    testWidgets('body is in ConstrainedBox with maxContentWidth at wide layout', (
      tester,
    ) async {
      await _setViewport(tester, 1000, 800);
      addTearDown(() => _resetViewport(tester));

      await tester.pumpWidget(_buildScaffold(width: 1000, selectedIndex: 0));
      await tester.pump();

      final constrained = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .firstWhere(
            (cb) => cb.constraints.maxWidth == AppDimensions.maxContentWidth,
            orElse: () => throw TestFailure(
              'ConstrainedBox with maxWidth=${AppDimensions.maxContentWidth} not found',
            ),
          );
      expect(constrained, isNotNull);
    });
  });

  group('ResponsiveScaffold — onDestinationSelected callback', () {
    testWidgets(
      'fires with correct index when bottom-nav tab is tapped (mobile)',
      (tester) async {
        await _setViewport(tester, 700, 800);
        addTearDown(() => _resetViewport(tester));

        int? tappedIndex;
        await tester.pumpWidget(
          _buildScaffold(
            width: 700,
            selectedIndex: 0,
            onSelected: (i) => tappedIndex = i,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Rides'));
        await tester.pump();
        expect(tappedIndex, equals(1));
      },
    );

    testWidgets(
      'fires with correct index when bottom-nav third tab is tapped (mobile)',
      (tester) async {
        await _setViewport(tester, 700, 800);
        addTearDown(() => _resetViewport(tester));

        int? tappedIndex;
        await tester.pumpWidget(
          _buildScaffold(
            width: 700,
            selectedIndex: 0,
            onSelected: (i) => tappedIndex = i,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Profile'));
        await tester.pump();
        expect(tappedIndex, equals(2));
      },
    );

    testWidgets(
      'fires with correct index when NavigationRail item is tapped (desktop)',
      (tester) async {
        await _setViewport(tester, 1000, 800);
        addTearDown(() => _resetViewport(tester));

        int? tappedIndex;
        await tester.pumpWidget(
          _buildScaffold(
            width: 1000,
            selectedIndex: 0,
            onSelected: (i) => tappedIndex = i,
          ),
        );
        await tester.pump();

        // NavigationRail renders destination labels; tap 'Rides' (index 1).
        await tester.tap(find.text('Rides'));
        await tester.pump();
        expect(
          tappedIndex,
          equals(1),
          reason:
              'tapping NavigationRail Rides destination should fire onDestinationSelected(1)',
        );
      },
    );

    testWidgets(
      'fires with correct index when NavigationRail third item is tapped (desktop)',
      (tester) async {
        await _setViewport(tester, 1000, 800);
        addTearDown(() => _resetViewport(tester));

        int? tappedIndex;
        await tester.pumpWidget(
          _buildScaffold(
            width: 1000,
            selectedIndex: 0,
            onSelected: (i) => tappedIndex = i,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Profile'));
        await tester.pump();
        expect(
          tappedIndex,
          equals(2),
          reason:
              'tapping NavigationRail Profile destination should fire onDestinationSelected(2)',
        );
      },
    );
  });

  group('ResponsiveScaffold — body content', () {
    testWidgets('body text is visible at mobile width', (tester) async {
      await _setViewport(tester, 700, 800);
      addTearDown(() => _resetViewport(tester));

      await tester.pumpWidget(_buildScaffold(width: 700, selectedIndex: 0));
      await tester.pump();

      expect(find.text('Body Content'), findsOneWidget);
    });

    testWidgets('body text is visible at desktop width', (tester) async {
      await _setViewport(tester, 1000, 800);
      addTearDown(() => _resetViewport(tester));

      await tester.pumpWidget(_buildScaffold(width: 1000, selectedIndex: 0));
      await tester.pump();

      expect(find.text('Body Content'), findsOneWidget);
    });

    testWidgets(
      'selectedIndex is reflected in BottomNavigationBar currentIndex',
      (tester) async {
        await _setViewport(tester, 700, 800);
        addTearDown(() => _resetViewport(tester));

        await tester.pumpWidget(_buildScaffold(width: 700, selectedIndex: 2));
        await tester.pump();

        final bar = tester.widget<BottomNavigationBar>(
          find.byType(BottomNavigationBar),
        );
        expect(bar.currentIndex, equals(2));
      },
    );

    testWidgets('selectedIndex is reflected in NavigationRail selectedIndex', (
      tester,
    ) async {
      await _setViewport(tester, 1000, 800);
      addTearDown(() => _resetViewport(tester));

      await tester.pumpWidget(_buildScaffold(width: 1000, selectedIndex: 2));
      await tester.pump();

      final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
      expect(rail.selectedIndex, equals(2));
    });
  });
}
