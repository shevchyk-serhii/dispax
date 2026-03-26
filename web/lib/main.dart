import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'l10n/app_localizations.dart';
import 'blocs/blocs.dart';
import 'auth/login_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'modules/ride_management/services/ride_service.dart';
import 'modules/schedule_management/services/schedule_service.dart';
import 'modules/core/services/websocket_service.dart';
import 'modules/core/services/push_notification_service.dart';

import 'widgets/common/splash_screen.dart';
import 'blocs/app_state/app_state_bloc.dart';
import 'blocs/app_state/app_state_event.dart';
import 'blocs/app_state/app_state_state.dart';
import 'theme/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('FCM background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await PushNotificationService.instance.initialize();
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
        BlocProvider<AppStateBloc>(
          create: (context) => AppStateBloc(),
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          return BlocProvider<RideBloc>(
            key: ValueKey(authState.isAuthenticated),
            create: (context) {
              final authBloc = context.read<AuthBloc>();
              return RideBloc(
                rideService: RideService(apiClient: authBloc.apiClient),
              );
            },
            child: BlocProvider<ScheduleBloc>(
              key: ValueKey('schedule_${authState.isAuthenticated}'),
              create: (context) {
                final authBloc = context.read<AuthBloc>();
                return ScheduleBloc(
                  scheduleService: ScheduleService(apiClient: authBloc.apiClient),
                );
              },
              child: const _AppWithWebSocket(),
            ),
          );
        },
      ),
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

      if (event.isRideAssigned || event.isRideStatusChanged || event.isRideCreated) {
        _refreshRides();
      }

      if (event.isGeofenceTriggered) {
        final geofenceName = event.geofenceName ?? 'Unknown zone';
        final isEntry = event.alertType == 'entry';
        final message = isEntry
            ? 'Driver entered $geofenceName'
            : 'Driver left $geofenceName';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isEntry ? Icons.arrow_downward : Icons.arrow_upward,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: isEntry ? Colors.green : Colors.red.shade700,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      if (event.isDriverApproaching) {
        final distance = event.distanceMeters;
        String message;
        if (distance == null) {
          message = 'Your driver is en route';
        } else if (distance <= 100) {
          message = 'Your driver has arrived!';
        } else if (distance <= 500) {
          message = 'Your driver is nearby!';
        } else {
          final km = (distance / 1000).toStringAsFixed(1);
          message = 'Your driver is about ${km}km away';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.directions_car, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: (distance != null && distance <= 100) ? Colors.green : Colors.blue,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    if (PushNotificationService.instance.isInitialized) {
      _fcmSubscription = PushNotificationService.instance.onMessage.listen((message) {
        if (!mounted) return;

        final type = message.data['type'];
        if (type == 'ride_assigned' || type == 'ride_status_changed' || type == 'ride_created') {
          _refreshRides();
        }
      });
    }
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
    return MaterialApp(
      title: 'Oktopus Taxi',
      theme: AppTheme.theme,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocBuilder<AppStateBloc, AppState>(
        builder: (context, appState) {
          if (!appState.isInitialized) {
            return SplashScreen(
              onInitializationComplete: () {
                context.read<AppStateBloc>().add(const AppInitialized());
              },
            );
          }

          return BlocBuilder<AuthBloc, AuthState>(
            builder: (context, authState) {
              if (authState.isLoading) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              return authState.isAuthenticated
                  ? const DashboardScreen()
                  : const LoginScreen();
            },
          );
        },
      ),
    );
  }
}
