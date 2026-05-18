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
  static const int _primaryTabCount = 4;

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
    _buildMoreScreen(),                          // 3: More menu
    // Extended screens (accessed via More)
    const DriverEarningsPanel(),                 // 4
    const PeakHoursPanel(),                      // 5
    const ClientValuePanel(),                    // 6
    const DriverScorecardPanel(),                // 7
    const DriverRatingsPanel(),                  // 8
    const AuditLogScreen(),                      // 9
    const AdminUsersScreen(),                    // 10
    const CompanySettingsScreen(),               // 11
    const ExpenseScreen(),                       // 12
    const RideExportScreen(),                    // 13
    const BillingScreen(),                       // 14
    const RideTemplatesScreen(),                 // 15
    const PaymentScreen(),                       // 16
    const PayrollScreen(),                       // 17
    const SettingsScreen(),                      // 18
    const GeofenceScreen(),                      // 19
    const DatevExportScreen(),                    // 20
    const BlacklistScreen(),                      // 21
    const EmergencyReassignmentScreen(),           // 22
    const RidePoolScreen(),                          // 23
    const NotificationCenterScreen(),                // 24
    const GdprScreen(),                               // 25
    const SessionManagementScreen(),                  // 26
    CreateRideScreen(rideBloc: _rideBloc),            // 27
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
        currentIndex: _mobileTabIndex < _primaryTabCount ? _mobileTabIndex : 3,
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
      _MoreMenuItem(Icons.add_circle, 'New Ride', 27, AppColors.success),
      _MoreMenuItem(Icons.euro, 'Earnings', 4, AppColors.dispatcherColor),
      _MoreMenuItem(Icons.access_time_filled, 'Peak Hours', 5, AppColors.warning),
      _MoreMenuItem(Icons.diamond, 'Client Value', 6, AppColors.clientColor),
      _MoreMenuItem(Icons.leaderboard, 'Drivers', 7, AppColors.driverColor),
      _MoreMenuItem(Icons.star, 'Ratings', 8, Colors.amber),
      _MoreMenuItem(Icons.history, 'Audit Log', 9, AppColors.info),
      _MoreMenuItem(Icons.admin_panel_settings, 'Admin', 10, AppColors.secretaryColor),
      _MoreMenuItem(Icons.business, 'Company', 11, AppColors.dispatcherColor),
      _MoreMenuItem(Icons.receipt_long, 'Expenses', 12, Colors.teal),
      _MoreMenuItem(Icons.download, 'Export', 13, Colors.indigo),
      _MoreMenuItem(Icons.request_quote, 'Billing', 14, Colors.brown),
      _MoreMenuItem(Icons.repeat, 'Templates', 15, Colors.deepPurple),
      _MoreMenuItem(Icons.payment, 'Payments', 16, Colors.cyan),
      _MoreMenuItem(Icons.account_balance_wallet, 'Payroll', 17, Colors.pink),
      _MoreMenuItem(Icons.share_location, 'Geofences', 19, Colors.deepOrange),
      _MoreMenuItem(Icons.account_balance, 'DATEV', 20, Colors.blueGrey),
      _MoreMenuItem(Icons.block, 'Blacklist', 21, Colors.red),
      _MoreMenuItem(Icons.emergency, 'Emergency', 22, const Color(0xFFD32F2F)),
      _MoreMenuItem(Icons.groups, 'Ride Pools', 23, Colors.indigo),
      _MoreMenuItem(Icons.notifications, 'Notifications', 24, AppColors.primary),
      _MoreMenuItem(Icons.privacy_tip, 'GDPR', 25, Colors.indigo),
      _MoreMenuItem(Icons.devices, 'Sessions', 26, Colors.deepPurple),
      _MoreMenuItem(Icons.settings, 'Settings', 18, AppColors.textSecondary),
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
