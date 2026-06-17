import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/models/person.dart';
import '../../../modules/core/navigation_helper.dart';
import '../../../modules/core/services/api_client.dart';
import '../../../modules/core/widgets/calendar_controls.dart';
import '../../../modules/schedule_management/services/schedule_service.dart';
import '../../../constants/app_colors.dart';
export '../../../modules/core/widgets/calendar_controls.dart'
    show CalendarViewType;
import 'month_view_widget.dart';
import 'week_view_widget.dart';
import 'day_view_widget.dart';

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
  bool _visibilityLoaded = false;

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
      // Check own visibility flag from the company list endpoint.
      final visibilityList = await _scheduleService.getCompanyVisibility();
      final myEntry = visibilityList.firstWhere(
        (v) => v['driverId']?.toString() == myId,
        orElse: () => {},
      );
      final canView =
          (myEntry['canViewOtherSchedules'] as bool?) ?? false;

      if (canView) {
        // Fetch the list of colleagues from the company driver endpoint.
        final driversResponse = await _apiClient.get('/users/drivers');
        List<Person> colleagues = [];
        if (driversResponse.statusCode == 200) {
          final List<dynamic> raw =
              jsonDecode(driversResponse.body) as List<dynamic>;
          colleagues =
              raw
                  .map((j) => Person.fromJson(j as Map<String, dynamic>))
                  .where((p) => p.id != myId) // exclude self
                  .toList();
        }
        if (mounted) {
          setState(() {
            _canViewOtherSchedules = true;
            _colleagues = colleagues;
            _visibilityLoaded = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _canViewOtherSchedules = false;
            _visibilityLoaded = true;
          });
        }
      }
    } catch (_) {
      // If the visibility check fails, gracefully fall back to own schedule only.
      if (mounted) setState(() => _visibilityLoaded = true);
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

    final String titleText =
        _selectedDriverName != null
            ? _selectedDriverName!
            : 'My Schedule';

    return Scaffold(
      appBar: AppBar(
        title:
            _canViewOtherSchedules && _colleagues.isNotEmpty
                ? _buildDriverDropdown(myId, titleText)
                : Text(titleText),
        backgroundColor: AppColors.infoStrong,
        foregroundColor: Colors.white,
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
                itemBuilder:
                    (BuildContext context) =>
                        <PopupMenuEntry<CalendarViewType>>[
                          const PopupMenuItem<CalendarViewType>(
                            value: CalendarViewType.month,
                            child: ListTile(
                              leading: Icon(Icons.calendar_month),
                              title: Text('Month View'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem<CalendarViewType>(
                            value: CalendarViewType.week,
                            child: ListTile(
                              leading: Icon(Icons.view_week),
                              title: Text('Week View'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const PopupMenuItem<CalendarViewType>(
                            value: CalendarViewType.day,
                            child: ListTile(
                              leading: Icon(Icons.view_day),
                              title: Text('Day View'),
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              selectedDayNotifier.value = DateTime.now();
            },
            tooltip: 'Go to Today',
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
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.infoStrong, AppColors.infoBg],
              stops: const [0.0, 0.3],
            ),
          ),
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          selectedDayNotifier.value = DateTime.now();
          viewTypeNotifier.value = CalendarViewType.day;
        },
        backgroundColor: AppColors.infoStrong,
        tooltip: 'Today\'s Schedule',
        child: const Icon(Icons.today, color: Colors.white),
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
        dropdownColor: AppColors.infoStrong,
        iconEnabledColor: Colors.white,
        style: const TextStyle(color: Colors.white, fontSize: 18),
        items: items,
        onChanged: _onDriverSelected,
      ),
    );
  }

  Widget buildCalendarView(CalendarViewType viewType, DateTime selectedDay) {
    switch (viewType) {
      case CalendarViewType.month:
        return MonthViewWidget(
          selectedDay: selectedDay,
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
          onRideSelected: (ride) {},
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
