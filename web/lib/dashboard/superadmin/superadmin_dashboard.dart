import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../modules/core/models/person.dart';
import '../../screens/superadmin_companies_screen.dart';
import '../../screens/superadmin_analytics_screen.dart';

/// Platform SuperAdmin dashboard.
///
/// Shown when a user with role [PersonRole.superAdmin] logs in.
/// Provides cross-tenant company management and platform analytics.
class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _selectedTab = 0;

  static const List<_Tab> _tabs = [
    _Tab(icon: Icons.business, label: 'Companies'),
    _Tab(icon: Icons.analytics, label: 'Analytics'),
    _Tab(icon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState.user;
        if (user == null || !user.isSuperAdmin) {
          // Role guard: redirect non-SuperAdmin users away from this screen.
          // In practice DashboardScreen already gates access; this is defence-in-depth.
          return const Scaffold(body: Center(child: Text('Access denied')));
        }

        return Scaffold(
          body: IndexedStack(
            index: _selectedTab,
            children: const [
              SuperAdminCompaniesScreen(),
              SuperAdminAnalyticsScreen(),
              _SuperAdminSettingsPlaceholder(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: (index) =>
                setState(() => _selectedTab = index),
            destinations: _tabs
                .map(
                  (t) =>
                      NavigationDestination(icon: Icon(t.icon), label: t.label),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _Tab {
  final IconData icon;
  final String label;
  const _Tab({required this.icon, required this.label});
}

class _SuperAdminSettingsPlaceholder extends StatelessWidget {
  const _SuperAdminSettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Platform Admin Settings — coming soon'));
  }
}
