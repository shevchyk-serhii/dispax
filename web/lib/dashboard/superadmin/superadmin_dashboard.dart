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
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Users & Roles',
    ),
    NavigationDestination(
      icon: Icon(Icons.history_outlined),
      selectedIcon: Icon(Icons.history),
      label: 'Audit Log',
    ),
  ];

  // IndexedStack keeps each screen's BLoC alive across tab switches so they
  // don't re-fetch (companies/airports) every time the tab is revisited.
  static const _tabBodies = [
    SuperAdminCompaniesScreen(),
    SuperAdminAnalyticsScreen(),
    SuperAdminAirportExitsScreen(),
    _SuperAdminUsersRolesPlaceholder(),
    _SuperAdminAuditLogPlaceholder(),
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

// ---------------------------------------------------------------------------
// Users & Roles placeholder
// TODO: Add /superadmin/users endpoint in backend to list all platform users
//       across tenants. Until then this screen is a placeholder.
// ---------------------------------------------------------------------------

class _SuperAdminUsersRolesPlaceholder extends StatelessWidget {
  const _SuperAdminUsersRolesPlaceholder();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: const [
                  Icon(Icons.people_outline, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Users & Roles',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.people_outline,
                  size: 48,
                  color: isDark ? AppColors.textLightDark : AppColors.textLight,
                ),
                const SizedBox(height: 16),
                Text(
                  'Users & Roles',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Requires a /superadmin/users endpoint (not yet available).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'TODO: will show Name | Email | Role | Status table\n'
                  'with role badges (Dispatcher amber, Secretary purple, Driver blue).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textLightDark
                        : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Audit Log placeholder
// TODO: Add /superadmin/audit endpoint in backend to expose platform audit log.
//       Until then this screen is a placeholder.
// ---------------------------------------------------------------------------

class _SuperAdminAuditLogPlaceholder extends StatelessWidget {
  const _SuperAdminAuditLogPlaceholder();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 14),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: const [
                  Icon(Icons.history_outlined, color: Colors.white, size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Audit Log',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.history_outlined,
                  size: 48,
                  color: isDark ? AppColors.textLightDark : AppColors.textLight,
                ),
                const SizedBox(height: 16),
                Text(
                  'Audit Log',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Requires a /superadmin/audit endpoint (not yet available).',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'TODO: will show timeline rows with colored dots\n'
                  '(green/blue/amber/red) + title + timestamp subtitle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textLightDark
                        : AppColors.textLight,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
