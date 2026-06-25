import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/core/navigation_helper.dart';
import '../../../modules/core/services/api_client.dart';
import '../../../modules/core/widgets/calendar_controls.dart';
import '../../../modules/schedule_management/services/schedule_service.dart';
import '../../../modules/ride_management/services/ride_service.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../../constants/app_colors.dart';
import '../../../screens/ride_details_screen.dart';
import '../../../l10n/app_localizations.dart';
export '../../../modules/core/widgets/calendar_controls.dart'
    show CalendarViewType;
import 'month_view_widget.dart';
import 'week_view_widget.dart';
import 'day_view_widget.dart';
import 'multi_column_view_widget.dart';

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

  // Rides for the currently selected colleague. Null while "My Schedule" is
  // selected — in that case the calendar reads the shared RideBloc (which is
  // loaded for the logged-in user and kept live across the dashboard tabs).
  // When a colleague is picked we load THEIR rides on demand and feed them to
  // the calendar via `ridesOverride`, so the shared RideBloc (and the other
  // tabs) is never disturbed.
  List<Ride>? _driverRides;
  bool _loadingDriverRides = false;
  String? _driverRidesError;
  // Guards against a stale response overwriting a newer selection.
  int _driverRidesRequestSeq = 0;

  late final ApiClient _apiClient;
  late final ScheduleService _scheduleService;
  late final RideService _rideService;

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<AuthBloc>().apiClient;
    _scheduleService = ScheduleService(apiClient: _apiClient);
    _rideService = RideService(apiClient: _apiClient);
    _initVisibility();
  }

  Future<void> _initVisibility() async {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated || authState.user == null) return;

    final myId = authState.user!.id;

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

    // Load own schedule initially.
    _loadScheduleFor(myId);
  }

  void _loadScheduleFor(String driverId) {
    context.read<ScheduleBloc>().add(
      ScheduleLoadDriverSchedule(driverId: driverId),
    );
  }

  void _onDriverSelected(String? driverId) {
    final authState = context.read<AuthBloc>().state;
    final myId = authState.user?.id;

    if (driverId == null || driverId == myId) {
      setState(() {
        _selectedDriverId = null;
        _selectedDriverName = null;
        // Back to own schedule: drop the colleague override so the calendar
        // reads the shared RideBloc again.
        _driverRides = null;
        _loadingDriverRides = false;
        _driverRidesError = null;
      });
      if (myId != null) _loadScheduleFor(myId);
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
        _selectedDriverId = driverId;
        _selectedDriverName = driver.name;
      });
      _loadScheduleFor(driverId);
      _loadDriverRides(driverId);
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
        _driverRidesError = 'Failed to load driver rides: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final myId = authState.user?.id;

    final String titleText = _selectedDriverName != null
        ? _selectedDriverName!
        : 'My Schedule';

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
                _canViewOtherSchedules &&
                _colleagues.isNotEmpty &&
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
              state.errorMessage!,
              isError: true,
            );
          }
        },
        child: SafeArea(
          child: Column(
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
                        onDatePickerTap: () => showDatePickerDialog(context),
                      );
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
    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(
        value: null,
        child: Text(
          'My Schedule',
          style: TextStyle(color: Colors.white),
          overflow: TextOverflow.ellipsis,
        ),
      ),
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
          onRideSelected: _openRideDetails,
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
              _driverRidesError ?? 'Failed to load driver rides',
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
    super.dispose();
  }
}
