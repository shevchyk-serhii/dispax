import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

/// Global test harness configuration, applied automatically to every test in
/// this package (Flutter discovers `flutter_test_config.dart` at the test root
/// and runs `testExecutable` once per test process).
///
/// Why this exists: Material's default ink splash on some target platforms is
/// `InkSparkle`, which lazily loads a GPU fragment shader via
/// `ui.FragmentProgram.fromAsset('shaders/ink_sparkle.frag')` the first time a
/// splash is created. Under the parallel `flutter test` runner that lazy load
/// races with asset-bundle registration inside the test process and
/// intermittently throws `Exception: Asset 'shaders/ink_sparkle.frag' not
/// found`, flaking unrelated widget tests (dispatcher dashboard, billing,
/// quick-login, ...).
///
/// Fix: warm the shader up once, synchronously awaited, before any test runs in
/// this process. After the first successful load the program is memoised in
/// dart:ui's shader registry, so every later `InkSparkle` tap reuses it and the
/// race window is gone. The warm-up is wrapped in a guard so that if the asset
/// genuinely cannot be loaded (e.g. a future SDK change) tests still execute
/// rather than failing in the harness. This is test-only; the production theme
/// in `lib/theme/app_theme.dart` is untouched.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();

  try {
    await ui.FragmentProgram.fromAsset('shaders/ink_sparkle.frag');
  } catch (_) {
    // Best-effort warm-up: never let a shader load failure block the suite.
  }

  await testMain();
}
