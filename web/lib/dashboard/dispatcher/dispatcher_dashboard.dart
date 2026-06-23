import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../blocs/blocs.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_dimensions.dart';
import '../../constants/app_styles.dart';
import '../../constants/lucide_compat.dart';
import '../../l10n/app_localizations.dart';
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
import '../../widgets/common/responsive_scaffold.dart';
import 'widgets/payroll_screen.dart';
import 'widgets/pending_rides_panel.dart';
import 'widgets/eta_alert_card.dart';
import 'widgets/driver_schedule_panel.dart';
import 'widgets/live_fleet_panel.dart';
import 'widgets/analytics_panel.dart';
import 'widgets/driver_earnings_panel.dart';
import 'widgets/peak_hours_panel.dart';
import 'widgets/client_value_panel.dart';
import 'widgets/driver_scorecard_panel.dart';
import 'widgets/driver_ratings_panel.dart';
import '../../modules/core/services/websocket_service.dart';
import '../../modules/core/services/user_service.dart';
import '../../modules/ride_management/models/ride.dart';
import 'dart:async';

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
  final List<EtaAtRiskInfo> _etaAlerts = [];
  StreamSubscription? _wsSubscription;

  /// driverId → display name, loaded from /users/drivers.
  /// Used to resolve the driver name for ETA alert cards.
  Map<String, String> _driverNames = {};

  // Screen index of the "New Ride" screen — used to detect unsaved form changes
  // when the user navigates away. This is a screen index, not a nav position.
  static const int _createRideTabIndex = 3;
  // Billing lives at screen index 15 in the extended list.
  static const int _billingTabIndex = 15;
  // Screen index for driver's own schedule (only when canDrive).
  static const int _myScheduleScreenIndex = 31;

  @override
  void initState() {
    super.initState();
    _wsSubscription = WebSocketService.instance.eventStream.listen((event) {
      if (!mounted) return;
      if (event.isEtaAtRisk) {
        final rideId = event.rideId ?? '';
        final driverId = event.etaRiskDriverId ?? '';
        // Resolve the human-readable name from the already-loaded driver list.
        // Fall back to the driverId string when the driver isn't in the cache.
        final driverName =
            _driverNames[driverId] ??
            (driverId.isNotEmpty ? driverId : 'Unknown');
        final etaMin = event.etaMinutes ?? 0;
        final pickupMin = event.pickupInMinutes ?? 0;
        final slack = event.slackMinutes ?? 0;
        setState(() {
          _etaAlerts.removeWhere((a) => a.rideId == rideId);
          _etaAlerts.insert(
            0,
            EtaAtRiskInfo(
              rideId: rideId,
              driverName: driverName,
              etaMinutes: etaMin,
              pickupInMinutes: pickupMin,
              slackMinutes: slack,
            ),
          );
        });
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _rideBloc = context.read<RideBloc>();
    _loadDriverNames();
  }

  /// Loads the driverId→name map from /users/drivers so that ETA alert cards
  /// can show a human-readable name instead of a UUID.
  Future<void> _loadDriverNames() async {
    final userService = UserService(
      apiClient: context.read<AuthBloc>().apiClient,
    );
    try {
      final drivers = await userService.getDrivers();
      if (!mounted) return;
      setState(() {
        _driverNames = {for (final d in drivers) d.id: d.name};
      });
    } catch (_) {
      // Names are a nicety; on failure the driverId string is shown as fallback.
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _createRideFormBloc.close();
    super.dispose();
  }

  Future<bool> _confirmLeaveCreateRide(BuildContext context) async {
    if (!_createRideFormBloc.state.isModified) return true;
    final l10n = AppLocalizations.of(context)!;
    final result = await showAdaptiveDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.discardChangesTitle),
        content: Text(l10n.discardChangesMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.stay),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.discard),
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
      PendingRidesPanel(
        etaAlerts: _etaAlerts,
        onDismissEtaAlert: (rideId) {
          setState(() => _etaAlerts.removeWhere((a) => a.rideId == rideId));
        },
      ), // 0: Home
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
    final l10n = AppLocalizations.of(context)!;
    final user = context.read<AuthBloc>().state.user;
    final canDrive = user?.canDrive ?? false;
    final navOrder = _navOrder(canDrive);
    final navDestinations = _buildNavDestinations(canDrive, l10n);

    return ResponsiveScaffold(
      destinations: navDestinations,
      selectedIndex: _navIndexForScreen(_mobileTabIndex, navOrder),
      onDestinationSelected: (navPos) async {
        final screenIndex = navOrder[navPos];
        if (_mobileTabIndex == _createRideTabIndex &&
            screenIndex != _createRideTabIndex) {
          final canLeave = await _confirmLeaveCreateRide(context);
          if (!canLeave) return;
        }
        setState(() => _mobileTabIndex = screenIndex);
      },
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= AppDimensions.breakpointDesktop) {
            return _buildSplitViewContent(context, canDrive);
          }
          return _buildMobileBody(canDrive);
        },
      ),
    );
  }

  /// Desktop split view: new-design dispatch board.
  ///
  /// Layout (top → bottom):
  ///   1. Top bar — title "Dispatch board" + subtitle + search pill + action buttons
  ///   2. Predictive ETA alert cards (if any)
  ///   3. Stats row (4 theme-aware tiles)
  ///   4. Two-column body: Pending Requests (left) | Live Fleet (right)
  ///
  /// The NavigationRail is provided by [ResponsiveScaffold]; this is the content
  /// area only (no extra Scaffold or navigation chrome).
  Widget _buildSplitViewContent(BuildContext context, bool canDrive) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top bar ─────────────────────────────────────────────────────
          _DispatchTopBar(
            canDrive: canDrive,
            onNewRide: () =>
                setState(() => _mobileTabIndex = _createRideTabIndex),
            onDriverMap: () => _openDriverMap(context),
            onBilling: () => _openBilling(context),
          ),
          // ── ETA alert cards ─────────────────────────────────────────────
          if (_etaAlerts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                children: _etaAlerts
                    .map(
                      (a) => EtaAlertCard(
                        info: a,
                        onDismiss: () => setState(
                          () => _etaAlerts.removeWhere(
                            (x) => x.rideId == a.rideId,
                          ),
                        ),
                        // Reassign is driven from the pending-requests panel
                        // below (the at-risk row's Reassign button); the
                        // top-of-board alert is dismiss-only by design.
                        onReassign: null,
                      ),
                    )
                    .toList(),
              ),
            ),
          // ── Stats row ───────────────────────────────────────────────────
          _StatsRow(etaAlerts: _etaAlerts),
          // ── Two-column body ─────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left: pending requests
                  Expanded(
                    flex: 5,
                    child: Container(
                      decoration: AppStyles.primaryCardDecorationOf(context),
                      clipBehavior: Clip.antiAlias,
                      child: PendingRidesPanel(
                        etaAlerts: _etaAlerts,
                        onDismissEtaAlert: (rideId) {
                          setState(
                            () => _etaAlerts.removeWhere(
                              (a) => a.rideId == rideId,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Right: live fleet
                  Expanded(flex: 4, child: const LiveFleetPanel()),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openBilling(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(l10n.billingScreenTitle)),
          body: const BillingScreen(),
        ),
      ),
    );
  }

  void _openDriverMap(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(l10n.driverMapMenuItem)),
          body: const DriverMapScreen(),
        ),
      ),
    );
  }

  /// Mobile body: the IndexedStack with all screens. The BottomNavigationBar is
  /// provided by [ResponsiveScaffold] at the mobile breakpoint.
  Widget _buildMobileBody(bool canDrive) {
    final screens = _buildAllScreens(canDrive);
    return IndexedStack(index: _mobileTabIndex, children: screens);
  }

  /// Returns the ordered list of screen indices for each bottom-nav position.
  ///
  /// canDrive=true  → 6 tabs: Home | Calendar | My Rides | New Ride | More | Billing
  /// canDrive=false → 6 tabs: Home | Schedule | Analytics | New Ride | More | Billing
  List<int> _navOrder(bool canDrive) => canDrive
      ? [
          0, // pos 0: Home (PendingRidesPanel)
          _myScheduleScreenIndex, // pos 1: Calendar (CalendarScheduleScreen)
          _driverMyRidesScreenIndex, // pos 2: My Rides (TodayRidesScreen)
          3, // pos 3: New Ride (CreateRideScreen)
          4, // pos 4: More
          _billingTabIndex, // pos 5: Billing
        ]
      : [
          0, // pos 0: Home
          1, // pos 1: Schedule
          2, // pos 2: Analytics
          3, // pos 3: New Ride
          4, // pos 4: More
          _billingTabIndex, // pos 5: Billing
        ];

  /// Builds the [NavigationDestination] list matching the nav order.
  List<NavigationDestination> _buildNavDestinations(
    bool canDrive,
    AppLocalizations l10n,
  ) {
    NavigationDestination dest(IconData icon, String label) =>
        NavigationDestination(icon: Icon(icon), label: label);

    if (canDrive) {
      return [
        dest(LucideCompat.clipboardList, l10n.homeTab),
        dest(LucideCompat.calendarDays, l10n.calendarTab),
        dest(Icons.directions_car_outlined, l10n.myRides),
        dest(Icons.add_circle_outline, l10n.newRideTab),
        dest(Icons.grid_view_outlined, l10n.moreTab),
        dest(Icons.request_quote_outlined, l10n.billingTab),
      ];
    }
    return [
      dest(LucideCompat.clipboardList, l10n.homeTab),
      dest(LucideCompat.calendarDays, l10n.scheduleTab),
      dest(Icons.bar_chart_outlined, l10n.analytics),
      dest(Icons.add_circle_outline, l10n.newRideTab),
      dest(Icons.grid_view_outlined, l10n.moreTab),
      dest(Icons.request_quote_outlined, l10n.billingTab),
    ];
  }

  /// Maps the current screen index to the highlighted bottom-nav position.
  /// Falls back to the "More" position (screen index 4) for screens not in nav.
  int _navIndexForScreen(int screenIndex, List<int> navOrder) {
    final idx = navOrder.indexOf(screenIndex);
    if (idx != -1) return idx;
    // Screen not in nav (e.g. an extended More-menu screen): highlight More.
    return navOrder.indexOf(4);
  }

  Widget _buildMoreScreen(bool canDrive) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      // Unified corporate graphite; only genuinely destructive items stay red.
      _MoreMenuItem(
        Icons.euro,
        l10n.earningsMenuItem,
        5,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.access_time_filled,
        l10n.peakHoursMenuItem,
        6,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.diamond,
        l10n.clientValueMenuItem,
        7,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.leaderboard,
        l10n.driversMenuItem,
        8,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.star,
        l10n.ratingsMenuItem,
        9,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.history,
        l10n.auditLogMenuItem,
        10,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.admin_panel_settings,
        l10n.adminMenuItem,
        11,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.business,
        l10n.companyMenuItem,
        12,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.receipt_long,
        l10n.expensesMenuItem,
        13,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.download,
        l10n.exportMenuItem,
        14,
        Theme.of(context).colorScheme.primary,
      ),
      // Billing (screen 15) now has a dedicated bottom-nav tab, so it's omitted here.
      _MoreMenuItem(
        Icons.repeat,
        l10n.templatesMenuItem,
        16,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.payment,
        l10n.paymentsMenuItem,
        17,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.account_balance_wallet,
        l10n.payrollMenuItem,
        18,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.settings,
        l10n.settingsMenuItem,
        19,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.share_location,
        l10n.geofencesMenuItem,
        20,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.account_balance,
        l10n.datevMenuItem,
        21,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(Icons.block, l10n.blacklistMenuItem, 22, AppColors.error),
      _MoreMenuItem(
        Icons.emergency,
        l10n.emergencyMenuItem,
        23,
        AppColors.error,
      ),
      _MoreMenuItem(
        Icons.groups,
        l10n.ridePoolsMenuItem,
        24,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.notifications,
        l10n.notificationsMenuItem,
        25,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.privacy_tip,
        l10n.gdprMenuItem,
        26,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.devices,
        l10n.sessionsMenuItem,
        27,
        Theme.of(context).colorScheme.primary,
      ),
      _MoreMenuItem(
        Icons.visibility,
        l10n.schedVisibilityMenuItem,
        28,
        Theme.of(context).colorScheme.primary,
      ),
      // Driver screens — only visible when this dispatcher also has the Driver role.
      // Analytics is removed from nav pos 2 when canDrive, so surface it here.
      if (canDrive)
        _MoreMenuItem(
          Icons.bar_chart,
          l10n.analyticsMenuItem,
          2,
          Theme.of(context).colorScheme.primary,
        ),
      if (canDrive)
        _MoreMenuItem(
          Icons.calendar_view_week,
          l10n.driverBoardMenuItem,
          1, // DriverSchedulePanel — removed from nav but still accessible via More
          Theme.of(context).colorScheme.primary,
        ),
      if (canDrive)
        _MoreMenuItem(
          Icons.map,
          l10n.driverMapMenuItem,
          _driverMapScreenIndex,
          Theme.of(context).colorScheme.primary,
        ),
      if (canDrive)
        _MoreMenuItem(
          Icons.directions_car,
          l10n.myRides,
          _driverMyRidesScreenIndex,
          Theme.of(context).colorScheme.primary,
        ),
    ];

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
              child: Text(
                l10n.moreScreenTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
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

// ─── Desktop split-view private widgets ─────────────────────────────────────

/// Top bar for the dispatcher split-view.
///
/// Pixel spec: pad 18/24 border-bottom; title 20px w700; subtitle 13px
/// textSecondary; search pill h38 w240 bg surfaceVariant border borderPrimary
/// radius 999; "+ New ride" graphite btn h38 13px w600 radius10; "Driver Map"
/// + "Billing" kept as FilledButton for existing test assertions.
class _DispatchTopBar extends StatelessWidget {
  final bool canDrive;
  final VoidCallback onNewRide;
  final VoidCallback onDriverMap;
  final VoidCallback onBilling;

  const _DispatchTopBar({
    required this.canDrive,
    required this.onNewRide,
    required this.onDriverMap,
    required this.onBilling,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final locale = Localizations.localeOf(context).toLanguageTag();
    final weekday = DateFormat('EEEE', locale).format(now);
    final dateStr =
        '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';

    return BlocBuilder<RideBloc, RideState>(
      buildWhen: (prev, curr) => prev.rides != curr.rides,
      builder: (context, rideState) {
        final activeCount = rideState.rides
            .where(
              (r) =>
                  r.status == RideStatus.assigned ||
                  r.status == RideStatus.inProgress,
            )
            .length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              bottom: BorderSide(color: colorScheme.outlineVariant),
            ),
          ),
          child: Row(
            children: [
              // Title + subtitle (Flexible so it shrinks if viewport is narrow)
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.dispatchBoardTitle,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.dispatcherSubtitle(weekday, dateStr, activeCount),
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Search pill
              SizedBox(
                height: 38,
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l10n.searchRidesDrivers,
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide(color: colorScheme.outline),
                    ),
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              const SizedBox(width: 12),
              // + New ride button (graphite)
              SizedBox(
                height: 38,
                child: FilledButton.icon(
                  onPressed: onNewRide,
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(l10n.newRideButtonLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Driver Map — visible only when canDrive; kept as FilledButton for tests.
              if (canDrive) ...[
                SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: onDriverMap,
                    icon: const Icon(Icons.map, size: 16),
                    label: Text(l10n.driverMapMenuItem),
                    style: AppStyles.accentButtonStyle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Billing — always visible; kept as FilledButton for tests.
              SizedBox(
                height: 38,
                child: FilledButton.icon(
                  onPressed: onBilling,
                  icon: const Icon(Icons.request_quote, size: 16),
                  label: Text(l10n.billingScreenTitle),
                  style: AppStyles.accentButtonStyle,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Stats row — 4 theme-aware tiles (Active / At risk / Drivers online /
/// On-time). Derives counts from RideBloc; falls back to placeholder strings
/// when data is unavailable.
///
/// Pixel spec: radius14 pad16/18 xs-shadow; label 12px textSecondary;
/// number 28px w700 (At-risk value red #DC2626).
class _StatsRow extends StatelessWidget {
  final List<EtaAtRiskInfo> etaAlerts;

  const _StatsRow({required this.etaAlerts});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return BlocBuilder<RideBloc, RideState>(
      buildWhen: (prev, curr) => prev.rides != curr.rides,
      builder: (context, state) {
        final activeCount = state.rides
            .where(
              (r) =>
                  r.status == RideStatus.assigned ||
                  r.status == RideStatus.inProgress,
            )
            .length;
        final atRiskCount = etaAlerts.length;
        final assignedCount = state.rides
            .where((r) => r.status == RideStatus.assigned)
            .length;
        final completedCount = state.rides
            .where((r) => r.status == RideStatus.completed)
            .length;
        final totalFinished = completedCount + atRiskCount;
        final onTimePct = totalFinished > 0
            ? ((completedCount / totalFinished) * 100).round()
            : 96; // placeholder when no data

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
          child: Row(
            children: [
              _StatTile(
                label: l10n.activeRidesLabel,
                value: '$activeCount',
                isRed: false,
              ),
              const SizedBox(width: 12),
              _StatTile(
                label: l10n.atRiskLabel,
                value: '$atRiskCount',
                isRed: atRiskCount > 0,
              ),
              const SizedBox(width: 12),
              _StatTile(
                label: l10n.driversOnlineLabel,
                value: '$assignedCount',
                isRed: false,
              ),
              const SizedBox(width: 12),
              _StatTile(
                label: l10n.onTimeLabel,
                value: '$onTimePct%',
                isRed: false,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isRed;

  const _StatTile({
    required this.label,
    required this.value,
    required this.isRed,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.surfaceDark : AppColors.surface;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderPrimary,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowXs,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: isRed
                    ? const Color(0xFFDC2626) // red-600
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
