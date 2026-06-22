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
import 'modules/core/services/websocket_service.dart';
import 'modules/core/services/push_notification_service.dart';
import 'modules/core/services/mapbox_service.dart';

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
  if (!kIsWeb) {
    MapboxOptions.setAccessToken(MapboxService.accessToken);
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

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
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
        context.read<RideBloc>().add(
          RideStatusReceived(
            rideId: event.rideId!,
            newStatus: RideStatus.fromString(event.newStatus!),
          ),
        );
        return;
      }
      if (event.isRideAssigned || event.isRideCreated) {
        _refreshRides();
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
