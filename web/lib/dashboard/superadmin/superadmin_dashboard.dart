import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../constants/app_colors.dart';
import '../../modules/core/models/person.dart';
import '../../screens/superadmin_companies_screen.dart';
import '../../screens/superadmin_analytics_screen.dart';
import '../../screens/superadmin_airport_exits_screen.dart';
import '../../widgets/common/responsive_scaffold.dart';

/// Platform SuperAdmin dashboard.
///
/// Shown when a user with role [PersonRole.superAdmin] logs in.
/// Provides cross-tenant company management and platform analytics.
/// At >= [AppDimensions.breakpointDesktop] (800 px) the graphite
/// [NavigationRail] is shown; below that a bottom nav bar is used.
class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  State<SuperAdminDashboard> createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _selectedTab = 0;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.business_outlined),
      selectedIcon: Icon(Icons.business),
      label: 'Companies',
    ),
    NavigationDestination(
      icon: Icon(Icons.analytics_outlined),
      selectedIcon: Icon(Icons.analytics),
      label: 'Analytics',
    ),
    NavigationDestination(
      icon: Icon(Icons.flight_land_outlined),
      selectedIcon: Icon(Icons.flight_land),
      label: 'Airport Exits',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'Settings',
    ),
  ];

  // IndexedStack keeps each screen's BLoC alive across tab switches so they
  // don't re-fetch (companies/airports) every time the tab is revisited.
  static const _tabBodies = [
    SuperAdminCompaniesScreen(),
    SuperAdminAnalyticsScreen(),
    SuperAdminAirportExitsScreen(),
    _SuperAdminSettingsPlaceholder(),
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

        return ResponsiveScaffold(
          destinations: _destinations,
          selectedIndex: _selectedTab,
          onDestinationSelected: (index) =>
              setState(() => _selectedTab = index),
          body: IndexedStack(index: _selectedTab, children: _tabBodies),
        );
      },
    );
  }
}

class _SuperAdminSettingsPlaceholder extends StatelessWidget {
  const _SuperAdminSettingsPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: AppColors.dispatcherGradient),
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: const [
                  Icon(Icons.settings, color: Colors.white, size: 24),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Platform Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Expanded(
          child: Center(child: Text('Platform Admin Settings — coming soon')),
        ),
      ],
    );
  }
}
