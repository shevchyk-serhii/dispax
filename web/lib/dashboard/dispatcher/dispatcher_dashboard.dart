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
import '../../screens/driver_map_screen.dart';
import '../driver/today_rides_screen.dart';
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
  final CreateRideFormBloc _createRideFormBloc = CreateRideFormBloc();

  // Primary tabs (shown in bottom nav)
  static const int _primaryTabCount = 5;
  static const int _createRideTabIndex = 3;
  // Billing lives in the extended screen list (index 15) but also gets a
  // dedicated bottom-nav tab so dispatchers can reach invoicing in one tap.
  static const int _billingTabIndex = 15;
  // Bottom-nav slots after the 5 primary tabs: Billing, then the More menu.
  static const int _billingNavIndex = 5;
  static const int _moreNavIndex = 6;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideBloc = context.read<RideBloc>();
  }

  @override
  void dispose() {
    _createRideFormBloc.close();
    super.dispose();
  }

  Future<bool> _confirmLeaveCreateRide(BuildContext context) async {
    if (!_createRideFormBloc.state.isModified) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'You have unsaved ride details. If you leave, they will be lost.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (result == true) {
      _createRideFormBloc.add(FormCleared());
    }
    return result ?? false;
  }

  // Screen indices for driver screens added at the end of the list (only when canDrive).
  // These must not collide with the hard-coded indices 0..27 above.
  static const int _driverMapScreenIndex = 28;
  static const int _driverMyRidesScreenIndex = 29;

  // All screens in order
  List<Widget> _buildAllScreens(bool canDrive) {
    final user = context.read<AuthBloc>().state.user;
    return [
      const PendingRidesPanel(), // 0: Home
      DriverSchedulePanel(
        // 1: Schedule
        selectedDate: _selectedDate,
        onDateChanged: (date) => setState(() => _selectedDate = date),
      ),
      const AnalyticsPanel(), // 2: Analytics
      CreateRideScreen(
        // 3: New Ride
        rideBloc: _rideBloc,
        formBloc: _createRideFormBloc,
        onCreated: () {
          if (user != null) {
            context.read<RideBloc>().add(RideLoadRequested(user: user));
          }
          setState(() => _mobileTabIndex = 0);
        },
      ),
      _buildMoreScreen(canDrive), // 4: More menu
      // Extended screens (accessed via More)
      const DriverEarningsPanel(), // 5
      const PeakHoursPanel(), // 6
      const ClientValuePanel(), // 7
      const DriverScorecardPanel(), // 8
      const DriverRatingsPanel(), // 9
      const AuditLogScreen(), // 10
      const AdminUsersScreen(), // 11
      const CompanySettingsScreen(), // 12
      const ExpenseScreen(), // 13
      const RideExportScreen(), // 14
      const BillingScreen(), // 15
      const RideTemplatesScreen(), // 16
      const PaymentScreen(), // 17
      const PayrollScreen(), // 18
      const SettingsScreen(), // 19
      const GeofenceScreen(), // 20
      const DatevExportScreen(), // 21
      const BlacklistScreen(), // 22
      const EmergencyReassignmentScreen(), // 23
      const RidePoolScreen(), // 24
      const NotificationCenterScreen(), // 25
      const GdprScreen(), // 26
      const SessionManagementScreen(), // 27
      // Driver screens — only meaningful when canDrive; appended at indices 28..29
      // so existing hard-coded indices are never renumbered.
      if (canDrive) const DriverMapScreen(), // 28
      if (canDrive) const TodayRidesScreen(), // 29
    ];
  }

  @override
  Widget build(BuildContext context) {
    final user = context.read<AuthBloc>().state.user;
    final canDrive = user?.canDrive ?? false;
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 800) {
            return _buildSplitView(context);
          }
          return _buildMobileView(canDrive);
        },
      ),
    );
  }

  Widget _buildSplitView(BuildContext context) {
    // This view is nested inside DashboardScreen's Scaffold (which owns the
    // UserAppBar), so it must not add its own AppBar. The wide layout has no
    // bottom nav, so surface a Billing entry point as a toolbar row on top.
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              // Filled accent button: AppColors.primary is near-black graphite
              // and was invisible on the dark dashboard background.
              child: FilledButton.icon(
                onPressed: () => _openBilling(context),
                icon: const Icon(Icons.request_quote, size: 20),
                label: const Text('Billing'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(flex: 2, child: const PendingRidesPanel()),
                Container(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(
                  flex: 3,
                  child: DriverSchedulePanel(
                    selectedDate: _selectedDate,
                    onDateChanged: (date) =>
                        setState(() => _selectedDate = date),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openBilling(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      // BillingScreen.build returns a bare Column (it's normally an IndexedStack
      // child), so wrap it in a Scaffold to get an app bar and a back button.
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Billing')),
        body: const BillingScreen(),
      ),
    ),
  );

  Widget _buildMobileView(bool canDrive) {
    final screens = _buildAllScreens(canDrive);
    return Scaffold(
      body: IndexedStack(index: _mobileTabIndex, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndexForScreen(_mobileTabIndex),
        onTap: (navIndex) async {
          // Map the tapped nav item back to a screen index: the first 5 are
          // primary tabs (1:1), Billing jumps to its extended-screen index, and
          // More opens the menu grid (screen index 4).
          final screenIndex = switch (navIndex) {
            _billingNavIndex => _billingTabIndex,
            _moreNavIndex => 4,
            _ => navIndex,
          };
          if (_mobileTabIndex == _createRideTabIndex &&
              screenIndex != _createRideTabIndex) {
            final canLeave = await _confirmLeaveCreateRide(context);
            if (!canLeave) return;
          }
          setState(() => _mobileTabIndex = screenIndex);
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.accent,
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
            icon: Icon(Icons.request_quote_outlined),
            activeIcon: Icon(Icons.request_quote),
            label: 'Billing',
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

  // Map the active screen index to the highlighted bottom-nav item: primary
  // tabs map 1:1, Billing has its own item, and any other extended screen
  // falls back to the More tab.
  int _navIndexForScreen(int screenIndex) {
    if (screenIndex < _primaryTabCount) return screenIndex;
    if (screenIndex == _billingTabIndex) return _billingNavIndex;
    return _moreNavIndex;
  }

  Widget _buildMoreScreen(bool canDrive) {
    final items = [
      // Unified corporate graphite; only genuinely destructive items stay red.
      _MoreMenuItem(
        Icons.euro,
        'Earnings',
        5,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.access_time_filled,
        'Peak Hours',
        6,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.diamond,
        'Client Value',
        7,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.leaderboard,
        'Drivers',
        8,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.star,
        'Ratings',
        9,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.history,
        'Audit Log',
        10,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.admin_panel_settings,
        'Admin',
        11,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.business,
        'Company',
        12,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.receipt_long,
        'Expenses',
        13,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.download,
        'Export',
        14,
        Theme.of(context).colorScheme.primary,
      ),
      // Billing (screen 15) now has a dedicated bottom-nav tab, so it's omitted here.
      _MoreMenuItem(
        Icons.repeat,
        'Templates',
        16,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.payment,
        'Payments',
        17,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.account_balance_wallet,
        'Payroll',
        18,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.settings,
        'Settings',
        19,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.share_location,
        'Geofences',
        20,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.account_balance,
        'DATEV',
        21,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(Icons.block, 'Blacklist', 22, AppColors.error),
      _MoreMenuItem(Icons.emergency, 'Emergency', 23, AppColors.error),
      _MoreMenuItem(
        Icons.groups,
        'Ride Pools',
        24,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.notifications,
        'Notifications',
        25,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.privacy_tip,
        'GDPR',
        26,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.devices,
        'Sessions',
        27,
        Theme.of(context).colorScheme.primary,
      ),
      // Driver screens — only visible when this dispatcher also has the Driver role
      if (canDrive)
        _MoreMenuItem(
          Icons.map,
          'Driver Map',
          _driverMapScreenIndex,
          Theme.of(context).colorScheme.primary,
        ),
      if (canDrive)
        _MoreMenuItem(
          Icons.directions_car,
          'My Rides',
          _driverMyRidesScreenIndex,
          Theme.of(context).colorScheme.primary,
        ),
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
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: item.color,
                        ),
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
