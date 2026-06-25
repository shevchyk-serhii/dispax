import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum CalendarViewType { month, week, day, multiColumn }

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
    final colorScheme = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: onPrevious,
            icon: Icon(
              Icons.chevron_left,
              color: colorScheme.onSurfaceVariant,
              size: 28,
            ),
            tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: GestureDetector(
              onTap: onDatePickerTap,
              child: Text(
                _getFormattedDate(selectedDay, locale),
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: Icon(
              Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
              size: 28,
            ),
            tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  String _getFormattedDate(DateTime date, String locale) {
    switch (viewType) {
      case CalendarViewType.month:
        return DateFormat.yMMMM(locale).format(date);
      case CalendarViewType.week:
        final startOfWeek = date.subtract(Duration(days: date.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        if (startOfWeek.month == endOfWeek.month) {
          final monthYear = DateFormat.yMMMM(locale).format(startOfWeek);
          return '$monthYear (${startOfWeek.day}–${endOfWeek.day})';
        } else {
          final start = DateFormat.MMMd(locale).format(startOfWeek);
          final end = DateFormat.yMMMd(locale).format(endOfWeek);
          return '$start – $end';
        }
      case CalendarViewType.day:
      case CalendarViewType.multiColumn:
        return DateFormat.yMMMMEEEEd(locale).format(date);
    }
  }
}
