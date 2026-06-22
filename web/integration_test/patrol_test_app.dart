import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dispax/main.dart'
    show MyApp, themeModeNotifier, themeFromString;
import 'package:dispax/firebase_options.dart';
import 'package:dispax/modules/core/services/mapbox_service.dart';

/// Minimal bootstrap for Patrol E2E tests.
///
/// Mirrors [main] from `lib/main.dart` but deliberately omits the FCM /
/// background-message wiring, which is unreliable on emulators/simulators that
/// lack Google Play services. Firebase init stays wrapped in try/catch so the
/// app still boots when Firebase is unavailable.
///
/// The API base URL is taken from `--dart-define=API_BASE_URL` (handled by
/// `ApiClient`); point it at the local `TestApplication` when running tests.
Future<void> bootstrapTestApp() async {
  final prefs = await SharedPreferences.getInstance();
  themeModeNotifier.value = themeFromString(prefs.getString('theme_mode'));

  // Mapbox token comes from --dart-define=MAPBOX_ACCESS_TOKEN. The map is not
  // exercised in E2E tests, so tolerate a missing token rather than crashing
  // the bootstrap.
  try {
    MapboxOptions.setAccessToken(MapboxService.accessToken);
  } catch (_) {
    // Token not provided in the test run; maps simply won't render.
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase is optional in the test environment.
  }

  runApp(const MyApp());
}
