import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'blocs/blocs.dart';
import 'auth/login_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'modules/ride_management/services/ride_service.dart';

import 'services/test_data_service.dart';
import 'widgets/common/splash_screen.dart';
import 'blocs/app_state/app_state_bloc.dart';
import 'blocs/app_state/app_state_event.dart';
import 'blocs/app_state/app_state_state.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
            child: MaterialApp(
              title: 'Oktopus Taxi',
              theme: AppTheme.theme,
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
            ),
          );
        },
      ),
    );
  }
}
