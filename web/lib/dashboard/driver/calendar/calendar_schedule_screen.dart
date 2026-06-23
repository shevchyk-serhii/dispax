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

  late final ApiClient _apiClient;
  late final ScheduleService _scheduleService;

  @override
  void initState() {
    super.initState();
    _apiClient = context.read<AuthBloc>().apiClient;
    _scheduleService = ScheduleService(apiClient: _apiClient);
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
        title: _canViewOtherSchedules && _colleagues.isNotEmpty
            ? _buildDriverDropdown(myId, titleText)
            : Text(titleText),
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
    switch (viewType) {
      case CalendarViewType.month:
        return MonthViewWidget(
          selectedDay: selectedDay,
          driverIdFilter: filterDriverId,
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

  @override
  void dispose() {
    _scheduleService.dispose();
    super.dispose();
  }
}
