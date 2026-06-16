import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../blocs/blocs.dart';
import '../auth/login_screen.dart';
import '../modules/core/models/person.dart';
import '../modules/core/navigation_helper.dart';
import '../modules/core/auth_helper.dart';
import '../widgets/widgets.dart';
import 'driver/driver_dashboard.dart';
import 'client/client_dashboard.dart';
import 'secretary/secretary_dashboard.dart';
import 'dispatcher/dispatcher_dashboard.dart';
import 'superadmin/superadmin_dashboard.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state.isUnauthenticated) {
              NavigationHelper.pushReplacement(context, const LoginScreen());
            }
          },
        ),
      ],
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, authState) {
          if (!authState.isAuthenticated || authState.user == null) {
            return const Scaffold(body: LoadingWidget());
          }

          final user = authState.user!;

          return Scaffold(
            appBar: UserAppBar(
              user: user,
              onProfile: () => ProfileDialog.show(context, user),
              onLogout: () => AuthHelper.logout(context),
            ),
            body: _buildDashboardContent(user.role),
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent(PersonRole role) {
    switch (role) {
      case PersonRole.driver:
        return const DriverDashboard();
      case PersonRole.client:
        return const ClientDashboard();
      case PersonRole.secretary:
        return const SecretaryDashboard();
      case PersonRole.dispatcher:
        return const DispatcherDashboard();
      case PersonRole.admin:
        return const DispatcherDashboard();
      case PersonRole.superAdmin:
        return const SuperAdminDashboard();
    }
  }
}
