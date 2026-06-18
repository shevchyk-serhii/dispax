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

void main() {
  group('ResponsiveScaffold', () {
    testWidgets('shows BottomNavigationBar at width 700 (< breakpoint)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildScaffold(width: 700, selectedIndex: 0));
      await tester.pump();

      expect(find.byType(BottomNavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('shows NavigationRail at width 1000 (>= breakpoint)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(_buildScaffold(width: 1000, selectedIndex: 0));
      await tester.pump();

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(BottomNavigationBar), findsNothing);
    });

    testWidgets('body is in ConstrainedBox with maxContentWidth at wide layout', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

    testWidgets('onDestinationSelected fires at bottom nav (mobile)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(700, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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
    });
  });
}
