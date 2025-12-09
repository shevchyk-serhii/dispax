import 'package:flutter/material.dart';

enum CalendarViewType { month, week, day }

class CalendarControls extends StatelessWidget {
  final DateTime selectedDay;
  final CalendarViewType viewType;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onDatePickerTap;

  const CalendarControls({
    super.key,
    required this.selectedDay,
    required this.viewType,
    required this.onPrevious,
    required this.onNext,
    required this.onDatePickerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left, color: Colors.white, size: 32),
            tooltip: 'Previous',
          ),
          Expanded(
            child: GestureDetector(
              onTap: onDatePickerTap,
              child: Column(
                children: [
                  Text(
                    _getFormattedDate(selectedDay),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    _getViewTypeLabel(viewType),
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(
              Icons.chevron_right,
              color: Colors.white,
              size: 32,
            ),
            tooltip: 'Next',
          ),
        ],
      ),
    );
  }

  String _getFormattedDate(DateTime date) {
    switch (viewType) {
      case CalendarViewType.month:
        return '${_getMonthName(date.month)} ${date.year}';
      case CalendarViewType.week:
        final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        if (startOfWeek.month == endOfWeek.month) {
          return '${_getMonthName(startOfWeek.month)} ${startOfWeek.day}-${endOfWeek.day}, ${startOfWeek.year}';
        } else {
          return '${_getMonthName(startOfWeek.month)} ${startOfWeek.day} - ${_getMonthName(endOfWeek.month)} ${endOfWeek.day}, ${startOfWeek.year}';
        }
      case CalendarViewType.day:
        return '${_getDayName(date.weekday)}, ${_getMonthName(date.month)} ${date.day}, ${date.year}';
    }
  }

  String _getViewTypeLabel(CalendarViewType viewType) {
    switch (viewType) {
      case CalendarViewType.month:
        return 'Month View';
      case CalendarViewType.week:
        return 'Week View';
      case CalendarViewType.day:
        return 'Day View';
    }
  }

  String _getMonthName(int month) {
    const monthNames = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return monthNames[month];
  }

  String _getDayName(int weekday) {
    const dayNames = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return dayNames[weekday];
  }
}
