// Regression: the "Map Integration Ready" title used AppStyles.titleLarge,
// whose hardcoded color is the light-theme AppColors.textPrimary (near-black).
// The title sits on a colorScheme.surface card, which is dark in dark mode, so
// the title was black-on-dark and invisible. It must resolve to the theme
// onSurface color instead.

import 'package:dispax/screens/simple_map_screen.dart';
import 'package:dispax/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('map-ready title uses theme onSurface color in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.darkTheme, home: const SimpleMapScreen()),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(find.text('Map Integration Ready'));
    final context = tester.element(find.text('Map Integration Ready'));
    expect(title.style?.color, Theme.of(context).colorScheme.onSurface);
    expect(title.style?.color, isNot(const Color(0xFF18181B)));
  });
}
