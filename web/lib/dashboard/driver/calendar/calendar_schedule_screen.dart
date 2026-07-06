import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/core/navigation_helper.dart';
import '../../../modules/core/services/api_client.dart';
import '../../../modules/core/widgets/calendar_controls.dart';
import '../../../modules/schedule_management/models/calendar_share.dart';
import '../../../modules/schedule_management/models/schedule_day.dart';
import '../../../modules/schedule_management/services/calendar_share_service.dart';
import '../../../modules/schedule_management/services/schedule_service.dart';
import '../../../modules/ride_management/services/ride_service.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';
import '../../../screens/ride_details_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/core/services/error_messages.dart';
export '../../../modules/core/widgets/calendar_controls.dart'
    show CalendarViewType;
import 'month_view_widget.dart';
import 'week_view_widget.dart';
import 'day_view_widget.dart';
import 'multi_column_view_widget.dart';
import 'shared_calendar_view.dart';
import 'widgets/shift_strip.dart';

class CalendarScheduleScreen extends StatefulWidget {
  const CalendarScheduleScreen({super.key});

  /// Exposes the shared view-type notifier for tests so they can drive the
  /// screen between calendar views without poking at private state.
  @visibleForTesting
  static ValueNotifier<CalendarViewType> get viewTypeNotifierForTest =>
      _CalendarScheduleScreenState.viewTypeNotifier;

  /// Exposes the shared selected-day notifier for tests so they can pin the
  /// calendar to a fixed date without driving the navigation controls.
  @visibleForTesting
  static ValueNotifier<DateTime> get selectedDayNotifierForTest =>
      _CalendarScheduleScreenState.selectedDayNotifier;

  @override
  State<CalendarScheduleScreen> createState() => _CalendarScheduleScreenState();
}

class _CalendarScheduleScreenState extends State<CalendarScheduleScreen> {
  static final ValueNotifier<DateTime> selectedDayNotifier =
      ValueNotifier<DateTime>(DateTime.now());
  static final ValueNotifier<CalendarViewType> viewTypeNotifier =
      ValueNotifier<CalendarViewType>(CalendarViewType.month);

  // Visibility state
  bool _canViewOtherSchedules = false;
  List<Person> _colleagues = [];
  String? _selectedDriverId; // null = own schedule
  String? _selectedDriverName;

  // Cross-company calendars shared with me (via invite codes). Selecting one
  // swaps the body to the read-only SharedCalendarView instead of feeding the
  // regular calendar widgets.
  List<CalendarShareGrant> _sharedWithMe = [];
  CalendarShareGrant? _selectedShare;

  /// Dropdown value prefix distinguishing a shared-calendar grant from a
  /// colleague's driverId.
  static const String _sharePrefix = 'share:';

  /// Work shifts of the currently selected person (self or the picked
  /// colleague), shared between the shift strip and the grid views. Cancelled
  /// shifts are already filtered out.
  List<ScheduleDay> _shifts = [];

  /// Guards against out-of-order shift responses when switching drivers.
  int _shiftsRequestSeq = 0;

  // Rides for the currently selected colleague. Null while "My Schedule" is
  // selected — in that case the calendar reads the shared RideBloc (which is
  // loaded for the logged-in user and kept live across the dashboard tabs).
  // When a colleague is picked we load THEIR rides on demand and feed them to
  // the calendar via `ridesOverride`, so the shared RideBloc (and the other
  // tabs) is never disturbed.
  List<Ride>? _driverRides;
  bool _loadingDriverRides = false;

  /// The caught error object of the last failed colleague-rides load; the
  /// error view maps it through friendlyError at render time (never render a
  /// raw exception string).
  Object? _driverRidesError;
  // Guards against a stale response overwriting a newer selection.
  int _driverRidesRequestSeq = 0;

  late final ApiClient _apiClient;
  late final ScheduleService _scheduleService;
  late final RideService _rideService;
  late final CalendarShareService _shareService;

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<AuthBloc>().apiClient;
    _scheduleService = ScheduleService(apiClient: _apiClient);
    _rideService = RideService(apiClient: _apiClient);
    _shareService = CalendarShareService(apiClient: _apiClient);
    _initVisibility();
    _loadSharedWithMe();
    _loadShifts();
  }

  /// Cross-company shares are independent of the intra-company visibility
  /// flag — load them unconditionally and degrade to none on any failure.
  Future<void> _loadSharedWithMe() async {
    try {
      final shares = await _shareService.getSharedWithMe();
      if (mounted) setState(() => _sharedWithMe = shares);
    } catch (_) {
      if (mounted) setState(() => _sharedWithMe = []);
    }
  }

  /// Loads the work shifts of the currently selected person (self by default,
  /// or the colleague picked in the dropdown) so both the shift strip and the
  /// calendar grid views can render them. Cancelled shifts are dropped here so
  /// every consumer sees the same working set. Degrades to empty on failure —
  /// the shifts are an overlay, never worth blocking the calendar.
  Future<void> _loadShifts() async {
    final targetDriverId =
        _selectedDriverId ?? context.read<AuthBloc>().state.user?.id;
    if (targetDriverId == null || targetDriverId.startsWith(_sharePrefix)) {
      if (mounted) setState(() => _shifts = []);
      return;
    }
    final seq = ++_shiftsRequestSeq;
    try {
      final shifts = await _scheduleService.getDriverSchedule(targetDriverId);
      if (mounted && seq == _shiftsRequestSeq) {
        setState(() {
          _shifts = shifts
              .where((s) => s.status != ScheduleDayStatus.cancelled)
              .toList();
        });
      }
    } catch (_) {
      if (mounted && seq == _shiftsRequestSeq) {
        setState(() => _shifts = []);
      }
    }
  }

  Future<void> _initVisibility() async {
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;
    if (!authState.isAuthenticated || user == null) return;

    final myId = user.id;

    try {
      // Check own visibility flag using the dedicated /me endpoint
      // (accessible to any authenticated user, including drivers).
      final myEntry = await _scheduleService.getMyVisibility();
      final canView = (myEntry['canViewOtherSchedules'] as bool?) ?? false;

      if (canView) {
        // Fetch the list of colleagues from the company driver endpoint.
        final driversResponse = await _apiClient.get('/users/drivers');
        List<Person> colleagues = [];
        if (driversResponse.statusCode == 200) {
          final List<dynamic> raw =
              jsonDecode(driversResponse.body) as List<dynamic>;
          colleagues = raw
              .map((j) => Person.fromJson(j as Map<String, dynamic>))
              .where((p) => p.id != myId) // exclude self
              .toList();
        }
        if (mounted) {
          setState(() {
            _canViewOtherSchedules = true;
            _colleagues = colleagues;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _canViewOtherSchedules = false;
          });
        }
      }
    } catch (_) {
      // If the visibility check fails, gracefully fall back to own schedule only.
      if (mounted) setState(() => _canViewOtherSchedules = false);
    }
  }

  void _onDriverSelected(String? driverId) {
    final authState = context.read<AuthBloc>().state;
    final myId = authState.user?.id;

    if (driverId != null && driverId.startsWith(_sharePrefix)) {
      final grantId = driverId.substring(_sharePrefix.length);
      final share = _sharedWithMe.where((g) => g.id == grantId).firstOrNull;
      setState(() {
        _selectedShare = share;
        _selectedDriverId = driverId;
        _selectedDriverName = share?.grantorName;
        _driverRides = null;
        _loadingDriverRides = false;
        _driverRidesError = null;
        _shifts = [];
      });
      return;
    }

    if (driverId == null || driverId == myId) {
      setState(() {
        _selectedShare = null;
        _selectedDriverId = null;
        _selectedDriverName = null;
        // Back to own schedule: drop the colleague override so the calendar
        // reads the shared RideBloc again.
        _driverRides = null;
        _loadingDriverRides = false;
        _driverRidesError = null;
      });
      _loadShifts();
    } else {
      final driver = _colleagues.firstWhere(
        (p) => p.id == driverId,
        orElse: () => Person(
          id: driverId,
          name: 'Driver',
          email: '',
          role: PersonRole.driver,
        ),
      );
      setState(() {
        _selectedShare = null;
        _selectedDriverId = driverId;
        _selectedDriverName = driver.name;
      });
      _loadDriverRides(driverId);
      _loadShifts();
    }
  }

  /// Loads the selected colleague's rides into [_driverRides] so the calendar
  /// can render them via `ridesOverride`. A monotonically increasing sequence
  /// guards against an earlier request resolving after a newer selection and
  /// clobbering it.
  Future<void> _loadDriverRides(String driverId) async {
    final seq = ++_driverRidesRequestSeq;
    setState(() {
      _loadingDriverRides = true;
      _driverRidesError = null;
    });
    try {
      final rides = await _rideService.getDriverRides(driverId);
      if (!mounted || seq != _driverRidesRequestSeq) return;
      setState(() {
        _driverRides = rides;
        _loadingDriverRides = false;
      });
    } catch (e) {
      if (!mounted || seq != _driverRidesRequestSeq) return;
      setState(() {
        _driverRides = const [];
        _loadingDriverRides = false;
        _driverRidesError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final myId = authState.user?.id;

    final String titleText = _selectedDriverName ?? 'My Schedule';

    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder<CalendarViewType>(
          valueListenable: viewTypeNotifier,
          builder: (context, viewType, child) {
            // The driver picker only filters the single-driver views
            // (month/week/day). The Board view already lays out every driver
            // in its own column, so the dropdown has no effect there — show a
            // plain title instead to avoid the misleading control.
            final canPickDriver =
                ((_canViewOtherSchedules && _colleagues.isNotEmpty) ||
                    _sharedWithMe.isNotEmpty) &&
                viewType != CalendarViewType.multiColumn;
            return canPickDriver
                ? _buildDriverDropdown(myId, titleText)
                : Text(titleText);
          },
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        elevation: 0,
        actions: [
          ValueListenableBuilder<CalendarViewType>(
            valueListenable: viewTypeNotifier,
            builder: (context, viewType, child) {
              return PopupMenuButton<CalendarViewType>(
                icon: const Icon(Icons.view_module),
                onSelected: (CalendarViewType result) {
                  // The Board view hides the share dropdown (its only reset
                  // control), while the body keeps rendering SharedCalendarView
                  // whenever _selectedShare is set — switching to Board with a
                  // shared calendar selected would strand the user on the
                  // share with no way back to the columns. Reset it here.
                  if (result == CalendarViewType.multiColumn &&
                      _selectedShare != null) {
                    setState(() => _selectedShare = null);
                  }
                  viewTypeNotifier.value = result;
                },
                itemBuilder: (BuildContext context) {
                  final l10n = AppLocalizations.of(context)!;
                  return <PopupMenuEntry<CalendarViewType>>[
                    PopupMenuItem<CalendarViewType>(
                      value: CalendarViewType.month,
                      child: ListTile(
                        leading: const Icon(Icons.calendar_month),
                        title: Text(l10n.monthView),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem<CalendarViewType>(
                      value: CalendarViewType.week,
                      child: ListTile(
                        leading: const Icon(Icons.view_week),
                        title: Text(l10n.weekView),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem<CalendarViewType>(
                      value: CalendarViewType.day,
                      child: ListTile(
                        leading: const Icon(Icons.view_day),
                        title: Text(l10n.dayView),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    if (_canViewOtherSchedules)
                      PopupMenuItem<CalendarViewType>(
                        value: CalendarViewType.multiColumn,
                        child: ListTile(
                          leading: const Icon(Icons.view_column),
                          title: Text(l10n.board),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                  ];
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              selectedDayNotifier.value = DateTime.now();
            },
            tooltip: AppLocalizations.of(context)!.goToday,
          ),
        ],
      ),
      body: BlocListener<RideBloc, RideState>(
        listener: (context, state) {
          if (state.hasError) {
            NavigationHelper.showSnackBar(
              context,
              friendlyError(
                state.error ?? state.errorMessage,
                AppLocalizations.of(context)!,
              ),
              isError: true,
            );
          }
        },
        child: SafeArea(
          // A cross-company shared calendar replaces the regular calendar
          // entirely — it pages weeks itself and renders PII-free chips only.
          child: _selectedShare != null
              ? SharedCalendarView(
                  grantId: _selectedShare!.id,
                  grantorName: _selectedShare!.grantorName,
                  grantorCompanyName: _selectedShare!.grantorCompanyName,
                  service: _shareService,
                )
              : Column(
                  children: [
                    ValueListenableBuilder<DateTime>(
                      valueListenable: selectedDayNotifier,
                      builder: (context, selectedDay, child) {
                        return ValueListenableBuilder<CalendarViewType>(
                          valueListenable: viewTypeNotifier,
                          builder: (context, viewType, child) {
                            return CalendarControls(
                              selectedDay: selectedDay,
                              viewType: viewType,
                              onPrevious: navigatePrevious,
                              onNext: navigateNext,
                              onDatePickerTap: () =>
                                  showDatePickerDialog(context),
                            );
                          },
                        );
                      },
                    ),
                    // Work-schedule strip: the selected driver's shifts for the
                    // selected day, with create/cancel for self (and for any
                    // company driver when the viewer is dispatcher/admin).
                    ValueListenableBuilder<DateTime>(
                      valueListenable: selectedDayNotifier,
                      builder: (context, selectedDay, child) {
                        return ValueListenableBuilder<CalendarViewType>(
                          valueListenable: viewTypeNotifier,
                          builder: (context, viewType, child) {
                            if (viewType == CalendarViewType.multiColumn) {
                              return const SizedBox.shrink();
                            }
                            return _buildShiftStrip(selectedDay);
                          },
                        );
                      },
                    ),
                    Expanded(
                      child: ValueListenableBuilder<CalendarViewType>(
                        valueListenable: viewTypeNotifier,
                        builder: (context, viewType, child) {
                          return ValueListenableBuilder<DateTime>(
                            valueListenable: selectedDayNotifier,
                            builder: (context, selectedDay, child) {
                              return buildCalendarView(viewType, selectedDay);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final cs = Theme.of(context).colorScheme;
          final l10n = AppLocalizations.of(context)!;
          return FloatingActionButton(
            heroTag: 'calendar_today',
            onPressed: () {
              selectedDayNotifier.value = DateTime.now();
              viewTypeNotifier.value = CalendarViewType.day;
            },
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            tooltip: l10n.todaysSchedule,
            child: const Icon(Icons.today),
          );
        },
      ),
    );
  }

  /// Drop-down widget shown in the AppBar when the driver has permission to
  /// view colleagues' schedules.
  Widget _buildDriverDropdown(String? myId, String titleText) {
    final l10n = AppLocalizations.of(context)!;
    final showColleagues = _canViewOtherSchedules && _colleagues.isNotEmpty;
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text(
          'My Schedule',
          style: TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      if (showColleagues)
        ..._colleagues.map(
          (p) => DropdownMenuItem<String?>(
            value: p.id,
            child: Text(
              p.name,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      if (_sharedWithMe.isNotEmpty) ...[
        DropdownMenuItem<String?>(
          enabled: false,
          value: '$_sharePrefix-header',
          child: Text(
            l10n.sharedWithMeGroupLabel,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        ..._sharedWithMe.map(
          (g) => DropdownMenuItem<String?>(
            value: '$_sharePrefix${g.id}',
            child: Text(
              '${g.grantorName} · ${g.grantorCompanyName}',
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    ];

    return DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: _selectedDriverId,
        dropdownColor: AppColors.primary,
        iconEnabledColor: Colors.white,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        items: items,
        onChanged: _onDriverSelected,
      ),
    );
  }

  /// The shift strip for the currently selected person: self by default, or
  /// the colleague picked in the AppBar dropdown. Creating/cancelling shifts
  /// is allowed for oneself and, for dispatchers/admins, for any company
  /// driver. Hidden while an external shared calendar is displayed (that view
  /// is read-only and already renders shifts itself).
  Widget _buildShiftStrip(DateTime selectedDay) {
    final user = context.read<AuthBloc>().state.user;
    final myId = user?.id;
    final targetDriverId = _selectedDriverId ?? myId;
    if (targetDriverId == null) return const SizedBox.shrink();

    final viewingSelf = _selectedDriverId == null;
    final isDispatcherOrAdmin =
        user != null &&
        (user.hasRole(PersonRole.dispatcher) || user.hasRole(PersonRole.admin));
    final canManage = viewingSelf || isDispatcherOrAdmin;

    return ShiftStrip(
      driverId: targetDriverId,
      selectedDay: selectedDay,
      canManage: canManage,
      service: _scheduleService,
      shifts: _shifts,
      onChanged: _loadShifts,
    );
  }

  void _openRideDetails(Ride ride) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RideDetailsScreen(ride: ride)),
    );
  }

  Widget buildCalendarView(CalendarViewType viewType, DateTime selectedDay) {
    // Markers must follow the driver picked in the AppBar dropdown. "My
    // Schedule" (_selectedDriverId == null) falls back to the current user's
    // own id, so the calendar only ever shows the selected driver's rides.
    final myId = context.read<AuthBloc>().state.user?.id;
    final filterDriverId = _selectedDriverId ?? myId;

    // When a colleague is selected, feed the calendar their rides explicitly
    // (loaded on demand) instead of the shared RideBloc — which only holds the
    // logged-in user's rides and feeds the other dashboard tabs. While that
    // load is in flight or has failed, show a spinner / error so the empty grid
    // is never mistaken for "no rides".
    final colleagueSelected = _selectedDriverId != null;
    if (colleagueSelected && _loadingDriverRides && _driverRides == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (colleagueSelected && _driverRidesError != null) {
      return _buildDriverRidesError();
    }
    final List<Ride>? ridesOverride = colleagueSelected
        ? (_driverRides ?? const <Ride>[])
        : null;

    switch (viewType) {
      case CalendarViewType.month:
        return MonthViewWidget(
          selectedDay: selectedDay,
          driverIdFilter: filterDriverId,
          ridesOverride: ridesOverride,
          shifts: _shifts,
          onDaySelected: (day) {
            selectedDayNotifier.value = day;
            viewTypeNotifier.value = CalendarViewType.day;
          },
          onMonthChanged: (day) {
            selectedDayNotifier.value = day;
          },
        );
      case CalendarViewType.week:
        return WeekViewWidget(
          selectedDay: selectedDay,
          driverIdFilter: filterDriverId,
          ridesOverride: ridesOverride,
          shifts: _shifts,
          onRideSelected: _openRideDetails,
          onDaySelected: (day) {
            selectedDayNotifier.value = day;
            viewTypeNotifier.value = CalendarViewType.day;
          },
          onWeekChanged: (day) {
            selectedDayNotifier.value = day;
          },
        );
      case CalendarViewType.day:
        return DayViewWidget(
          selectedDay: selectedDay,
          driverIdFilter: filterDriverId,
          ridesOverride: ridesOverride,
          shifts: _shifts,
          onRideSelected: _openRideDetails,
          // A price edit refreshes the shared RideBloc, but the colleague view
          // renders from the local [_driverRides] override — refetch it so the
          // selected driver's card shows the new price without a manual reload.
          onRidesChanged: colleagueSelected && _selectedDriverId != null
              ? () => _loadDriverRides(_selectedDriverId!)
              : null,
        );
      case CalendarViewType.multiColumn:
        final authState = context.read<AuthBloc>().state;
        final self = authState.user;
        final selfPerson = self != null
            ? Person(
                id: self.id,
                name: self.name,
                email: self.email,
                role: PersonRole.driver,
              )
            : null;
        final allDrivers = [if (selfPerson != null) selfPerson, ..._colleagues];
        return MultiColumnViewWidget(
          selectedDay: selectedDay,
          drivers: allDrivers,
          // Cross-company calendars shared with me appear as extra read-only
          // columns after the company drivers.
          externalShares: _sharedWithMe,
          shareService: _shareService,
          onRideSelected: _openRideDetails,
        );
    }
  }

  void navigatePrevious() {
    final currentView = viewTypeNotifier.value;
    final currentDate = selectedDayNotifier.value;

    switch (currentView) {
      case CalendarViewType.month:
        selectedDayNotifier.value = DateTime(
          currentDate.year,
          currentDate.month - 1,
          1,
        );
        break;
      case CalendarViewType.week:
        selectedDayNotifier.value = currentDate.subtract(
          const Duration(days: 7),
        );
        break;
      case CalendarViewType.day:
      case CalendarViewType.multiColumn:
        selectedDayNotifier.value = currentDate.subtract(
          const Duration(days: 1),
        );
        break;
    }
  }

  void navigateNext() {
    final currentView = viewTypeNotifier.value;
    final currentDate = selectedDayNotifier.value;

    switch (currentView) {
      case CalendarViewType.month:
        selectedDayNotifier.value = DateTime(
          currentDate.year,
          currentDate.month + 1,
          1,
        );
        break;
      case CalendarViewType.week:
        selectedDayNotifier.value = currentDate.add(const Duration(days: 7));
        break;
      case CalendarViewType.day:
      case CalendarViewType.multiColumn:
        selectedDayNotifier.value = currentDate.add(const Duration(days: 1));
        break;
    }
  }

  void showDatePickerDialog(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: selectedDayNotifier.value,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    ).then((pickedDate) {
      if (pickedDate != null) {
        selectedDayNotifier.value = pickedDate;
      }
    });
  }

  /// Error placeholder shown when loading the selected colleague's rides fails,
  /// with a retry that re-issues the load for the current selection.
  Widget _buildDriverRidesError() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 12),
            Text(
              friendlyError(_driverRidesError, AppLocalizations.of(context)!),
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                final id = _selectedDriverId;
                if (id != null) _loadDriverRides(id);
              },
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _scheduleService.dispose();
    _rideService.dispose();
    _shareService.dispose();
    super.dispose();
  }
}
