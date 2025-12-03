import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'blocs/blocs.dart';
import 'auth/login_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'services/ride_service.dart';
import 'services/mapbox_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Mapbox
  MapboxOptions.setAccessToken(MapboxService.accessToken);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthBloc>(
      create: (context) => AuthBloc()..add(const AuthInitializeRequested()),
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
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                useMaterial3: true,
              ),
              home: BlocBuilder<AuthBloc, AuthState>(
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
              ),
            ),
          );
        },
      ),
    );
  }
}
