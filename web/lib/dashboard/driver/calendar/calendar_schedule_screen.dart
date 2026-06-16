import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../blocs/blocs.dart';
import '../../../modules/core/navigation_helper.dart';
import '../../../modules/core/widgets/calendar_controls.dart';
export '../../../modules/core/widgets/calendar_controls.dart'
    show CalendarViewType;
import 'month_view_widget.dart';
import 'week_view_widget.dart';
import 'day_view_widget.dart';
import '../../../constants/app_colors.dart';

class CalendarScheduleScreen extends StatelessWidget {
  const CalendarScheduleScreen({super.key});

  static final ValueNotifier<DateTime> selectedDayNotifier =
      ValueNotifier<DateTime>(DateTime.now());
  static final ValueNotifier<CalendarViewType> viewTypeNotifier =
      ValueNotifier<CalendarViewType>(CalendarViewType.month);

  void _loadDriverSchedule(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState.isAuthenticated && authState.user != null) {
      context.read<ScheduleBloc>().add(
        ScheduleLoadDriverSchedule(driverId: authState.user!.id),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    _loadDriverSchedule(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
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
                itemBuilder: (BuildContext context) =>
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
}
