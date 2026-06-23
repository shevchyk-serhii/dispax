import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';

import 'l10n/app_localizations.dart';
import 'locale_notifier.dart';
import 'blocs/blocs.dart';
import 'auth/login_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'modules/ride_management/services/ride_service.dart';
import 'modules/ride_management/models/ride.dart';
import 'modules/schedule_management/services/schedule_service.dart';
import 'modules/core/services/mapbox_service.dart';
import 'modules/core/services/websocket_service.dart';
import 'modules/core/services/push_notification_service.dart';

import 'blocs/app_state/app_state_bloc.dart';
import 'theme/app_theme.dart';
import 'constants/app_colors.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final notification = message.notification;
  if (notification == null) return;

  const androidDetails = AndroidNotificationDetails(
    'ride_notifications',
    'Ride Notifications',
    channelDescription: 'Notifications about ride assignments and updates',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );
  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
  );

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ),
  );
  await plugin.show(
    (message.messageId ??
            message.sentTime?.millisecondsSinceEpoch.toString() ??
            '')
        .hashCode,
    notification.title,
    notification.body,
    const NotificationDetails(android: androidDetails, iOS: iosDetails),
  );
}

final themeModeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

ThemeMode themeFromString(String? value) => switch (value) {
  'light' => ThemeMode.light,
  'dark' => ThemeMode.dark,
  _ => ThemeMode.system,
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  themeModeNotifier.value = themeFromString(prefs.getString('theme_mode'));
  localeNotifier.value = localeFromString(prefs.getString('language'));

  // Mapbox Maps is not supported on web; its initializer calls
  // bool.fromEnvironment non-const, which throws on the DDC/web compiler
  // and crashes main() before runApp (white screen). Skip it on web.
  if (!kIsWeb && MapboxService.accessTokenOrEmpty.isNotEmpty) {
    MapboxOptions.setAccessToken(MapboxService.accessTokenOrEmpty);
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Skip messaging on iOS simulator
    final bool isIosSimulator =
        !kIsWeb &&
        Platform.isIOS &&
        !Platform.environment.containsKey('SIMULATOR_DEVICE_NAME');

    if (!isIosSimulator) {
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );
      await PushNotificationService.instance.initialize();
    }
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc()..add(const AuthInitializeRequested()),
        ),
        BlocProvider<AppStateBloc>(create: (context) => AppStateBloc()),
      ],
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: themeModeNotifier,
        builder: (context, themeMode, _) => ValueListenableBuilder<Locale?>(
          valueListenable: localeNotifier,
          builder: (context, locale, _) => MaterialApp(
            title: 'Dispax',
            theme: AppTheme.theme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            locale: locale,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const AppRoot(),
          ),
        ),
      ),
    );
  }
}

/// Dev-only autologin: when the app is launched with
/// `--dart-define=DEV_AUTOLOGIN=<role>` (client | driver | dispatcher |
/// secretary | superadmin), it logs the matching test account in automatically
/// so each simulator opens straight into that role. Used by `make dev-roles`.
/// Empty in normal/release builds — a no-op.
const String _devAutologinRole = String.fromEnvironment('DEV_AUTOLOGIN');

const Map<String, String> _devAutologinEmails = {
  'client': 'client1@bmw.de',
  'driver': 'driver1@dispax.de',
  'dispatcher': 'dispatcher@dispax.de',
  'secretary': 'secretary@dispax.de',
  'superadmin': 'superadmin@dispax.de',
};

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  // Guards the dev autologin so it fires at most once per app launch (e.g. it
  // must not re-fire after the user manually logs out during a dev session).
  bool _autologinAttempted = false;

  void _maybeAutologin(AuthState state) {
    if (_autologinAttempted) return;
    if (_devAutologinRole.isEmpty) return;
    // Wait for the initial auth check to resolve before acting.
    if (state.status == AuthStatus.initial ||
        state.status == AuthStatus.loading) {
      return;
    }

    final email = _devAutologinEmails[_devAutologinRole];
    if (email == null) {
      debugPrint('⚠️ DEV_AUTOLOGIN="$_devAutologinRole" is not a known role');
      _autologinAttempted = true;
      return;
    }

    // If a previous session for a DIFFERENT account is restored from the
    // Keychain (which survives an app uninstall on iOS), log out first so the
    // target role's login takes effect — otherwise the simulator would keep
    // whoever was logged in last.
    if (state.isAuthenticated) {
      if (state.user?.email == email) {
        _autologinAttempted = true; // already the right account
        return;
      }
      debugPrint('🔁 Dev autologin: switching ${state.user?.email} → $email');
      context.read<AuthBloc>().add(const AuthLogoutRequested());
      return; // re-enters this listener as unauthenticated, then logs in below
    }

    _autologinAttempted = true;
    debugPrint('🔐 Dev autologin as $_devAutologinRole ($email)');
    context.read<AuthBloc>().add(
      AuthLoginRequested(email: email, password: 'password123'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      // Fire the dev autologin once the initial auth check resolves to
      // unauthenticated, reusing the normal login event.
      listener: (context, authState) => _maybeAutologin(authState),
      builder: (context, authState) {
        if (authState.status == AuthStatus.initial ||
            authState.status == AuthStatus.loading) {
          return const Scaffold(
            backgroundColor: AppColors.brand900,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (authState.isAuthenticated) {
          final authBloc = context.read<AuthBloc>();
          return MultiBlocProvider(
            key: ValueKey('auth_zone_${authState.user?.id}'),
            providers: [
              BlocProvider<RideBloc>(
                create: (context) => RideBloc(
                  rideService: RideService(apiClient: authBloc.apiClient),
                ),
              ),
              BlocProvider<ScheduleBloc>(
                create: (context) => ScheduleBloc(
                  scheduleService: ScheduleService(
                    apiClient: authBloc.apiClient,
                  ),
                ),
              ),
            ],
            child: const _AppWithWebSocket(),
          );
        }

        // Unauthenticated: if a dev autologin is pending, it was just dispatched
        // by the listener — briefly show the login screen until it resolves.
        return const LoginScreen();
      },
    );
  }
}

class _AppWithWebSocket extends StatefulWidget {
  const _AppWithWebSocket();

  @override
  State<_AppWithWebSocket> createState() => _AppWithWebSocketState();
}

class _AppWithWebSocketState extends State<_AppWithWebSocket> {
  StreamSubscription? _wsSubscription;
  StreamSubscription? _fcmSubscription;

  @override
  void initState() {
    super.initState();
    _wsSubscription = WebSocketService.instance.eventStream.listen((event) {
      if (!mounted) return;
      if (event.isRideStatusChanged &&
          event.rideId != null &&
          event.newStatus != null) {
        final parsedStatus = RideStatus.fromStringOrNull(event.newStatus!);
        if (parsedStatus != null) {
          context.read<RideBloc>().add(
            RideStatusReceived(rideId: event.rideId!, newStatus: parsedStatus),
          );
        } else {
          debugPrint(
            'WS RideStatusChanged: unrecognised status "${event.newStatus}" for ride ${event.rideId} — skipping BLoC update',
          );
        }
        return;
      }
      if (event.isRideAssigned || event.isRideCreated) {
        _refreshRides();
      }
      if (event.isRideDetailsUpdated) {
        _refreshRides();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ride details were updated.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    });

    _fcmSubscription = PushNotificationService.instance.onMessage.listen((
      message,
    ) {
      if (!mounted) return;
      final type = message.data['type'];
      if (type == 'ride_assigned' ||
          type == 'ride_updated' ||
          type == 'ride_created') {
        _refreshRides();
      }
    });
  }

  void _refreshRides() {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<RideBloc>().add(RideRefreshRequested(user: authState.user!));
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _fcmSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const DashboardScreen();
  }
}
