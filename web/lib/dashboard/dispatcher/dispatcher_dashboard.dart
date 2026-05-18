import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/blocs.dart';
import '../../constants/app_colors.dart';
import '../../screens/create_ride_screen.dart';
import '../../screens/settings_screen.dart';
import '../../screens/expense_screen.dart';
import '../../screens/ride_export_screen.dart';
import '../../screens/billing_screen.dart';
import '../../screens/ride_templates_screen.dart';
import '../../screens/payment_screen.dart';
import '../../screens/company_settings_screen.dart';
import '../../screens/audit_log_screen.dart';
import '../../screens/admin_users_screen.dart';
import '../../screens/geofence_screen.dart';
import '../../screens/datev_export_screen.dart';
import '../../screens/blacklist_screen.dart';
import '../../screens/emergency_reassignment_screen.dart';
import '../../screens/ride_pool_screen.dart';
import '../../screens/notification_center_screen.dart';
import '../../screens/gdpr_screen.dart';
import '../../screens/session_management_screen.dart';
import 'widgets/payroll_screen.dart';
import 'widgets/pending_rides_panel.dart';
import 'widgets/driver_schedule_panel.dart';
import 'widgets/analytics_panel.dart';
import 'widgets/driver_earnings_panel.dart';
import 'widgets/peak_hours_panel.dart';
import 'widgets/client_value_panel.dart';
import 'widgets/driver_scorecard_panel.dart';
import 'widgets/driver_ratings_panel.dart';

class DispatcherDashboard extends StatefulWidget {
  const DispatcherDashboard({super.key});

  @override
  State<DispatcherDashboard> createState() => _DispatcherDashboardState();
}

class _DispatcherDashboardState extends State<DispatcherDashboard> {
  DateTime _selectedDate = DateTime.now();
  int _mobileTabIndex = 0;
  late RideBloc _rideBloc;

  // Primary tabs (shown in bottom nav)
  static const int _primaryTabCount = 5;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideBloc = context.read<RideBloc>();
  }

  // All screens in order
  List<Widget> get _allScreens => [
    const PendingRidesPanel(),                  // 0: Home
    DriverSchedulePanel(                         // 1: Schedule
      selectedDate: _selectedDate,
      onDateChanged: (date) => setState(() => _selectedDate = date),
    ),
    const AnalyticsPanel(),                      // 2: Analytics
    CreateRideScreen(rideBloc: _rideBloc),       // 3: New Ride
    _buildMoreScreen(),                          // 4: More menu
    // Extended screens (accessed via More)
    const DriverEarningsPanel(),                 // 5
    const PeakHoursPanel(),                      // 6
    const ClientValuePanel(),                    // 7
    const DriverScorecardPanel(),                // 8
    const DriverRatingsPanel(),                  // 9
    const AuditLogScreen(),                      // 10
    const AdminUsersScreen(),                    // 11
    const CompanySettingsScreen(),               // 12
    const ExpenseScreen(),                       // 13
    const RideExportScreen(),                    // 14
    const BillingScreen(),                       // 15
    const RideTemplatesScreen(),                 // 16
    const PaymentScreen(),                       // 17
    const PayrollScreen(),                       // 18
    const SettingsScreen(),                      // 19
    const GeofenceScreen(),                      // 20
    const DatevExportScreen(),                   // 21
    const BlacklistScreen(),                     // 22
    const EmergencyReassignmentScreen(),         // 23
    const RidePoolScreen(),                      // 24
    const NotificationCenterScreen(),            // 25
    const GdprScreen(),                          // 26
    const SessionManagementScreen(),             // 27
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return _buildSplitView();
          }
          return _buildMobileView();
        },
      ),
    );
  }

  Widget _buildSplitView() {
    return Container(
      color: AppColors.background,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: const PendingRidesPanel(),
          ),
          Container(width: 1, color: Colors.grey.shade300),
          Expanded(
            flex: 3,
            child: DriverSchedulePanel(
              selectedDate: _selectedDate,
              onDateChanged: (date) => setState(() => _selectedDate = date),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileView() {
    return Scaffold(
      body: IndexedStack(
        index: _mobileTabIndex,
        children: _allScreens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _mobileTabIndex < _primaryTabCount ? _mobileTabIndex : 4,
        onTap: (index) => setState(() => _mobileTabIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.dispatcherColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'New Ride',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
        ],
      ),
    );
  }

  Widget _buildMoreScreen() {
    final items = [
      _MoreMenuItem(Icons.euro, 'Earnings', 5, AppColors.dispatcherColor),
      _MoreMenuItem(Icons.access_time_filled, 'Peak Hours', 6, AppColors.warning),
      _MoreMenuItem(Icons.diamond, 'Client Value', 7, AppColors.clientColor),
      _MoreMenuItem(Icons.leaderboard, 'Drivers', 8, AppColors.driverColor),
      _MoreMenuItem(Icons.star, 'Ratings', 9, Colors.amber),
      _MoreMenuItem(Icons.history, 'Audit Log', 10, AppColors.info),
      _MoreMenuItem(Icons.admin_panel_settings, 'Admin', 11, AppColors.secretaryColor),
      _MoreMenuItem(Icons.business, 'Company', 12, AppColors.dispatcherColor),
      _MoreMenuItem(Icons.receipt_long, 'Expenses', 13, Colors.teal),
      _MoreMenuItem(Icons.download, 'Export', 14, Colors.indigo),
      _MoreMenuItem(Icons.request_quote, 'Billing', 15, Colors.brown),
      _MoreMenuItem(Icons.repeat, 'Templates', 16, Colors.deepPurple),
      _MoreMenuItem(Icons.payment, 'Payments', 17, Colors.cyan),
      _MoreMenuItem(Icons.account_balance_wallet, 'Payroll', 18, Colors.pink),
      _MoreMenuItem(Icons.settings, 'Settings', 19, AppColors.textSecondary),
      _MoreMenuItem(Icons.share_location, 'Geofences', 20, Colors.deepOrange),
      _MoreMenuItem(Icons.account_balance, 'DATEV', 21, Colors.blueGrey),
      _MoreMenuItem(Icons.block, 'Blacklist', 22, Colors.red),
      _MoreMenuItem(Icons.emergency, 'Emergency', 23, const Color(0xFFD32F2F)),
      _MoreMenuItem(Icons.groups, 'Ride Pools', 24, Colors.indigo),
      _MoreMenuItem(Icons.notifications, 'Notifications', 25, AppColors.primary),
      _MoreMenuItem(Icons.privacy_tip, 'GDPR', 26, Colors.indigo),
      _MoreMenuItem(Icons.devices, 'Sessions', 27, Colors.deepPurple),
    ];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: AppColors.dispatcherGradient),
          ),
          child: const SafeArea(
            bottom: false,
            child: Text(
              'More',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                onTap: () => setState(() => _mobileTabIndex = item.screenIndex),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: item.color.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.color.withAlpha(60)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(item.icon, color: item.color, size: 28),
                      const SizedBox(height: 8),
                      Text(
                        item.label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: item.color),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MoreMenuItem {
  final IconData icon;
  final String label;
  final int screenIndex;
  final Color color;

  const _MoreMenuItem(this.icon, this.label, this.screenIndex, this.color);
}
