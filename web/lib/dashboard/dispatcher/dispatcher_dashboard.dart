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
import '../../screens/driver_schedule_visibility_screen.dart';
import '../../screens/driver_map_screen.dart';
import '../driver/today_rides_screen.dart';
import '../driver/calendar/calendar_schedule_screen.dart';
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
  // Bottom-nav item positions (0-based):
  //   0 Home | 1 Schedule | 2 Analytics/MyRides | 3 New Ride | 4 More | 5 Billing | [6 My Schedule]
  // NOTE: More is at position 4 (= _primaryTabCount - 1) so that screen indices
  // 0..4 map 1:1 to nav positions 0..4 and the _navIndexForScreen fallback
  // (screenIndex < _primaryTabCount) routes screen 4 → nav 4 (More).
  static const int _moreNavIndex = 4;
  static const int _billingNavIndex = 5;
  // "My Schedule" is a dispatcher-who-also-drives extra: it gets its own
  // bottom-nav slot (appended after Billing) and its own extended-screen index,
  // both present only when canDrive.
  static const int _myScheduleNavIndex = 6;
  static const int _myScheduleScreenIndex = 31;

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
  // These must not collide with the hard-coded indices 0..28 (DriverScheduleVisibilityScreen).
  static const int _driverMapScreenIndex = 29;
  static const int _driverMyRidesScreenIndex = 30;

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
      const DriverScheduleVisibilityScreen(), // 28
      // Driver screens — only meaningful when canDrive; appended at indices 29..30
      // so existing hard-coded indices are never renumbered.
      if (canDrive) const DriverMapScreen(), // 29
      if (canDrive) const TodayRidesScreen(), // 30
      if (canDrive) const CalendarScheduleScreen(), // 31: My Schedule
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
    final canDrive = context.read<AuthBloc>().state.user?.canDrive ?? false;
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (canDrive) ...[
                    FilledButton.icon(
                      onPressed: () => _openDriverMap(context),
                      icon: const Icon(Icons.map, size: 20),
                      label: const Text('Driver Map'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  // Filled accent button: AppColors.primary is near-black graphite
                  // and was invisible on the dark dashboard background.
                  FilledButton.icon(
                    onPressed: () => _openBilling(context),
                    icon: const Icon(Icons.request_quote, size: 20),
                    label: const Text('Billing'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
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

  void _openDriverMap(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Driver Map')),
        body: const DriverMapScreen(),
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
          // Map the tapped nav item back to a screen index.
          // Nav positions: 0 Home | 1 Schedule | 2 Analytics(or MyRides if canDrive)
          //                | 3 New Ride | 4 More | 5 Billing | [6 My Schedule]
          final screenIndex = switch (navIndex) {
            2 when canDrive => _driverMyRidesScreenIndex, // My Rides tab
            _billingNavIndex => _billingTabIndex,
            _moreNavIndex => 4, // More menu grid lives at screen index 4
            _myScheduleNavIndex => _myScheduleScreenIndex,
            _ => navIndex, // 0,1,2(!canDrive),3 map 1:1 to screen indices
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
        items: [
          // pos 0
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          // pos 1
          const BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month_outlined),
            activeIcon: Icon(Icons.calendar_month),
            label: 'Schedule',
          ),
          // pos 2: Analytics for pure dispatcher; My Rides when canDrive.
          if (canDrive)
            const BottomNavigationBarItem(
              icon: Icon(Icons.directions_car_outlined),
              activeIcon: Icon(Icons.directions_car),
              label: 'My Rides',
            )
          else
            const BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart),
              label: 'Analytics',
            ),
          // pos 3
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            activeIcon: Icon(Icons.add_circle),
            label: 'New Ride',
          ),
          // pos 4: More menu grid (screen index 4 — satisfies 1:1 primary mapping).
          const BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined),
            activeIcon: Icon(Icons.grid_view),
            label: 'More',
          ),
          // pos 5: Billing (screen index 15).
          const BottomNavigationBarItem(
            icon: Icon(Icons.request_quote_outlined),
            activeIcon: Icon(Icons.request_quote),
            label: 'Billing',
          ),
          // pos 6: Only when this dispatcher also drives — their own driver schedule.
          if (canDrive)
            const BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note),
              label: 'My Schedule',
            ),
        ],
      ),
    );
  }

  // Map the active screen index to the highlighted bottom-nav item.
  // Nav positions: 0 Home | 1 Schedule | 2 Analytics/MyRides | 3 New Ride
  //               | 4 More | 5 Billing | [6 My Schedule]
  // Screen indices 0..4 map 1:1 to nav positions 0..4 (primary tabs).
  // Screen 30 (My Rides) highlights nav 2 when canDrive is true.
  int _navIndexForScreen(int screenIndex) {
    final canDrive = context.read<AuthBloc>().state.user?.canDrive ?? false;
    if (screenIndex == _driverMyRidesScreenIndex && canDrive) return 2;
    if (screenIndex < _primaryTabCount) return screenIndex;
    if (screenIndex == _billingTabIndex) return _billingNavIndex;
    if (screenIndex == _myScheduleScreenIndex) return _myScheduleNavIndex;
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
      _MoreMenuItem(
        Icons.visibility,
        'Sched. Visibility',
        28,
        Theme.of(context).colorScheme.primary,
      ),
      // Driver screens — only visible when this dispatcher also has the Driver role.
      // Analytics is removed from nav pos 2 when canDrive, so surface it here.
      if (canDrive)
        _MoreMenuItem(
          Icons.bar_chart,
          'Analytics',
          2,
          Theme.of(context).colorScheme.primary,
        ),
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
