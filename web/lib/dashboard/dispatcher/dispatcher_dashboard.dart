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
import '../../screens/abholschild_screen.dart';
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
import '../../screens/dispatcher_driver_schedules_screen.dart';
import '../../screens/calendar_sharing_screen.dart';
import '../../screens/driver_map_screen.dart';
import '../driver/today_rides_screen.dart';
import '../driver/calendar/calendar_schedule_screen.dart';
import '../../widgets/common/responsive_scaffold.dart';
import 'widgets/payroll_screen.dart';
import 'widgets/pending_rides_panel.dart';
import 'arrivals_board_screen.dart';
import 'widgets/eta_alert_card.dart';
import 'widgets/driver_schedule_panel.dart';
import 'widgets/live_fleet_panel.dart';
import 'widgets/analytics_panel.dart';
import 'widgets/driver_earnings_panel.dart';
import 'widgets/peak_hours_panel.dart';
import 'widgets/client_value_panel.dart';
import 'widgets/driver_scorecard_panel.dart';
import 'widgets/driver_ratings_panel.dart';
import '../secretary/widgets/client_list_panel.dart';
import '../../modules/core/services/websocket_service.dart';
import '../../modules/core/services/user_service.dart';
import '../../modules/core/models/websocket_event.dart';
import '../../modules/ride_management/models/ride.dart';
import 'dart:async';

/// Maps a live `RideConfirmed` / `RideRejected` WebSocket event to an in-place
/// [RideStatusReceived] patch for the shared [RideBloc].
///
/// The pending reload those events also trigger only refreshes Requested rides
/// (see `RideBloc._mergePending`), so non-requested rows keep whatever status
/// their local copy had. Without this patch a driver confirm never flips the
/// dispatcher board's badge to Confirmed, and a reject leaves a stale Assigned
/// copy in the list next to the freshly reloaded Requested one.
RideStatusReceived? liveStatusPatch(WebSocketEvent event) {
  final rideId = event.rideId;
  if (rideId == null) return null;
  if (event.isRideConfirmed) {
    return RideStatusReceived(rideId: rideId, newStatus: RideStatus.confirmed);
  }
  if (event.isRideRejected) {
    return RideStatusReceived(rideId: rideId, newStatus: RideStatus.requested);
  }
  return null;
}

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
  // Billing lives at screen index 15 in the extended list. It is reached from
  // the More grid (no longer a bottom-nav tab).
  static const int _billingTabIndex = 15;
  // Settings lives at screen index 19 and is the last bottom-nav tab (mirrors
  // the driver dashboard, where Settings is the final destination).
  static const int _settingsTabIndex = 19;
  // Screen index for driver's own schedule (only when canDrive).
  // DispatcherDriverSchedulesScreen sits at 29, Manage Clients at 30, the arrivals
  // board at 31 and Calendar Sharing at 32, so the canDrive-gated driver screens
  // shift to 33..35.
  static const int _myScheduleScreenIndex = 35;

  @override
  void initState() {
    super.initState();
    _wsSubscription = WebSocketService.instance.eventStream.listen((event) {
      if (!mounted) return;
      if (event.isRideConfirmed || event.isRideRejected) {
        // Patch the ride's status in place FIRST: the pending reload below
        // only refreshes Requested rides (the bloc's merge keeps non-requested
        // rows exactly as they were), so without this patch the Assigned-tab
        // badge never flips to Confirmed live, and a rejected ride would be
        // kept as a stale Assigned copy next to its fresh Requested twin.
        final patch = liveStatusPatch(event);
        if (patch != null) _rideBloc.add(patch);
        // Refresh ride list so the dispatcher sees updated status and frame color.
        _rideBloc.add(const RideLoadPendingRequested());
        if (event.isRideRejected) {
          final reason = event.rejectionReason ?? 'No reason provided';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ride rejected by driver: $reason'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
      // Live MUC flight-board updates (FlightStatusUpdated) are patched into the
      // shared RideBloc by the global WebSocket listener in main.dart via
      // RideFlightStatusReceived, so every screen (dispatcher, driver, client)
      // reflects gate/terminal/status changes without a per-screen handler.
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

  // Driver Schedules viewer (index 29): always available to dispatchers.
  static const int _driverSchedulesScreenIndex = 29;
  // Manage Clients (index 30): always available — added unconditionally before the
  // canDrive-gated driver screens so its index never shifts with canDrive.
  static const int _manageClientsScreenIndex = 30;
  // Arrivals board (index 31): always available — added unconditionally before the
  // canDrive-gated driver screens so its index never shifts with canDrive.
  static const int _arrivalsBoardScreenIndex = 31;
  // Calendar Sharing (index 32): always available — cross-company sharing of the
  // caller's personal calendar; added unconditionally so its index never shifts.
  static const int _calendarSharingScreenIndex = 32;
  // Screen indices for driver screens added at the end of the list (only when canDrive).
  // These must not collide with the hard-coded indices 0..32.
  static const int _driverMapScreenIndex = 33;
  static const int _driverMyRidesScreenIndex = 34;

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
      const DispatcherDriverSchedulesScreen(), // 29
      // Manage Clients (30) — unconditional, so its index is stable regardless of
      // canDrive. Self-contained ClientBloc so it works without a provider above.
      BlocProvider<ClientBloc>(
        create: (_) => ClientBloc(
          userService: UserService(
            apiClient: context.read<AuthBloc>().apiClient,
          ),
        )..add(const ClientLoadRequested()),
        child: const ClientListPanel(),
      ), // 30: Manage Clients
      const ArrivalsBoardScreen(), // 31: MUC arrivals board
      const CalendarSharingScreen(), // 32: cross-company calendar sharing
      // Driver screens — only meaningful when canDrive; appended at indices 33..35
      // so existing hard-coded indices are never renumbered.
      if (canDrive) const DriverMapScreen(), // 33
      if (canDrive) const TodayRidesScreen(), // 34
      if (canDrive) const CalendarScheduleScreen(), // 35: My Schedule
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
  /// canDrive=true  → 6 tabs: Home | Calendar | My Rides | New Ride | More | Settings
  /// canDrive=false → 6 tabs: Home | Schedule | Analytics | New Ride | More | Settings
  List<int> _navOrder(bool canDrive) => canDrive
      ? [
          0, // pos 0: Home (PendingRidesPanel)
          _myScheduleScreenIndex, // pos 1: Calendar (CalendarScheduleScreen)
          _driverMyRidesScreenIndex, // pos 2: My Rides (TodayRidesScreen)
          3, // pos 3: New Ride (CreateRideScreen)
          4, // pos 4: More
          _settingsTabIndex, // pos 5: Settings (SettingsScreen)
        ]
      : [
          0, // pos 0: Home
          1, // pos 1: Schedule
          2, // pos 2: Analytics
          3, // pos 3: New Ride
          4, // pos 4: More
          _settingsTabIndex, // pos 5: Settings (SettingsScreen)
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
        dest(LucideCompat.settings, l10n.settings),
      ];
    }
    return [
      dest(LucideCompat.clipboardList, l10n.homeTab),
      dest(LucideCompat.calendarDays, l10n.scheduleTab),
      dest(Icons.bar_chart_outlined, l10n.analytics),
      dest(Icons.add_circle_outline, l10n.newRideTab),
      dest(Icons.grid_view_outlined, l10n.moreTab),
      dest(LucideCompat.settings, l10n.settings),
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
    final color = Theme.of(context).colorScheme.primary;
    // Tiles are grouped by category for discoverability: Analytics → Operations
    // → Finance → Admin → Governance. Unified corporate graphite; only genuinely
    // destructive items stay red. canDrive-gated tiles sit inside their category.
    final items = [
      // ── Analytics ──
      _MoreMenuItem(Icons.euro, l10n.earningsMenuItem, 5, color),
      _MoreMenuItem(Icons.access_time_filled, l10n.peakHoursMenuItem, 6, color),
      _MoreMenuItem(Icons.diamond, l10n.clientValueMenuItem, 7, color),
      _MoreMenuItem(Icons.leaderboard, l10n.driversMenuItem, 8, color),
      _MoreMenuItem(Icons.star, l10n.ratingsMenuItem, 9, color),
      // Analytics is removed from nav pos 2 when canDrive, so surface it here.
      if (canDrive)
        _MoreMenuItem(Icons.bar_chart, l10n.analyticsMenuItem, 2, color),

      // ── Operations ──
      _MoreMenuItem(Icons.groups, l10n.ridePoolsMenuItem, 24, color),
      _MoreMenuItem(Icons.repeat, l10n.templatesMenuItem, 16, color),
      _MoreMenuItem(Icons.visibility, l10n.schedVisibilityMenuItem, 28, color),
      _MoreMenuItem(
        Icons.event_note,
        l10n.driverSchedules,
        _driverSchedulesScreenIndex,
        color,
      ),
      _MoreMenuItem(
        Icons.ios_share,
        l10n.calendarSharingMenuItem,
        _calendarSharingScreenIndex,
        color,
      ),
      _MoreMenuItem(
        Icons.people,
        l10n.manageClientsTitle,
        _manageClientsScreenIndex,
        color,
      ),
      _MoreMenuItem(
        Icons.flight_land,
        l10n.arrivalsBoardTitle,
        _arrivalsBoardScreenIndex,
        color,
      ),
      // Abholschild (pickup sign) — a full-screen route, not a tab, so it carries
      // a custom onTap instead of a screen index.
      _MoreMenuItem(
        Icons.airport_shuttle,
        l10n.pickupSignMenuItem,
        -1,
        color,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const AbholschildScreen()),
        ),
      ),
      // DriverSchedulePanel — removed from nav when canDrive, accessible here.
      if (canDrive)
        _MoreMenuItem(
          Icons.calendar_view_week,
          l10n.driverBoardMenuItem,
          1,
          color,
        ),
      if (canDrive)
        _MoreMenuItem(
          Icons.map,
          l10n.driverMapMenuItem,
          _driverMapScreenIndex,
          color,
        ),

      // ── Finance ──
      _MoreMenuItem(
        Icons.request_quote_outlined,
        l10n.billingTab,
        _billingTabIndex,
        color,
      ),
      _MoreMenuItem(Icons.payment, l10n.paymentsMenuItem, 17, color),
      _MoreMenuItem(
        Icons.account_balance_wallet,
        l10n.payrollMenuItem,
        18,
        color,
      ),
      _MoreMenuItem(Icons.receipt_long, l10n.expensesMenuItem, 13, color),
      _MoreMenuItem(Icons.download, l10n.exportMenuItem, 14, color),
      _MoreMenuItem(Icons.account_balance, l10n.datevMenuItem, 21, color),

      // ── Admin ──
      _MoreMenuItem(Icons.admin_panel_settings, l10n.adminMenuItem, 11, color),
      _MoreMenuItem(Icons.business, l10n.companyMenuItem, 12, color),
      _MoreMenuItem(Icons.history, l10n.auditLogMenuItem, 10, color),
      _MoreMenuItem(Icons.share_location, l10n.geofencesMenuItem, 20, color),
      _MoreMenuItem(Icons.devices, l10n.sessionsMenuItem, 27, color),
      _MoreMenuItem(Icons.notifications, l10n.notificationsMenuItem, 25, color),

      // ── Governance ──
      _MoreMenuItem(Icons.privacy_tip, l10n.gdprMenuItem, 26, color),
      _MoreMenuItem(Icons.block, l10n.blacklistMenuItem, 22, AppColors.error),
      _MoreMenuItem(
        Icons.emergency,
        l10n.emergencyMenuItem,
        23,
        AppColors.error,
      ),

      // Settings (screen 19) is the last bottom-nav tab, so it is omitted here.
      // My Rides (screen 31) is already the third bottom-nav tab when canDrive,
      // so it is not duplicated in the More grid.
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
                onTap:
                    item.onTap ??
                    () => setState(() => _mobileTabIndex = item.screenIndex),
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

  /// Optional custom tap handler. When set (e.g. to push a full-screen route),
  /// it runs instead of switching to [screenIndex]. Items that just switch tabs
  /// leave this null and pass a real [screenIndex].
  final VoidCallback? onTap;

  const _MoreMenuItem(
    this.icon,
    this.label,
    this.screenIndex,
    this.color, {
    this.onTap,
  });
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
