import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/core/widgets/calendar_controls.dart';
import '../../../modules/ride_management/models/ride.dart';
import '../../driver/calendar/month_view_widget.dart';
import '../../driver/calendar/week_view_widget.dart';
import 'client_day_view_widget.dart';

/// Full-screen calendar view for the client ride history.
///
/// Supports month, week, and day views. Tapping a ride card calls
/// [onRideSelected]. Navigation and date picker are included.
class ClientCalendarView extends StatefulWidget {
  final void Function(Ride) onRideSelected;

  const ClientCalendarView({super.key, required this.onRideSelected});

  @override
  State<ClientCalendarView> createState() => _ClientCalendarViewState();
}

class _ClientCalendarViewState extends State<ClientCalendarView> {
  DateTime _selectedDay = DateTime.now();
  CalendarViewType _viewType = CalendarViewType.month;

  void _navigatePrevious() {
    setState(() {
      switch (_viewType) {
        case CalendarViewType.month:
          _selectedDay = DateTime(_selectedDay.year, _selectedDay.month - 1, 1);
          break;
        case CalendarViewType.week:
          _selectedDay = _selectedDay.subtract(const Duration(days: 7));
          break;
        case CalendarViewType.day:
          _selectedDay = _selectedDay.subtract(const Duration(days: 1));
          break;
        case CalendarViewType.multiColumn:
          _selectedDay = _selectedDay.subtract(const Duration(days: 1));
          break;
      }
    });
  }

  void _navigateNext() {
    setState(() {
      switch (_viewType) {
        case CalendarViewType.month:
          _selectedDay = DateTime(_selectedDay.year, _selectedDay.month + 1, 1);
          break;
        case CalendarViewType.week:
          _selectedDay = _selectedDay.add(const Duration(days: 7));
          break;
        case CalendarViewType.day:
          _selectedDay = _selectedDay.add(const Duration(days: 1));
          break;
        case CalendarViewType.multiColumn:
          _selectedDay = _selectedDay.add(const Duration(days: 1));
          break;
      }
    });
  }

  void _showDatePicker(BuildContext context) {
    showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    ).then((picked) {
      if (picked != null) {
        setState(() => _selectedDay = picked);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // View type segmented button — stretched to the full width so the
        // three segments share the row evenly (otherwise "Month" is wider than
        // "Day" and the control looks misaligned).
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<CalendarViewType>(
              expandedInsets: EdgeInsets.zero,
              segments: [
                ButtonSegment(
                  value: CalendarViewType.month,
                  label: Text(l10n.monthView),
                ),
                ButtonSegment(
                  value: CalendarViewType.week,
                  label: Text(l10n.weekView),
                ),
                ButtonSegment(
                  value: CalendarViewType.day,
                  label: Text(l10n.dayView),
                ),
              ],
              selected: {_viewType},
              onSelectionChanged: (selection) {
                setState(() => _viewType = selection.first);
              },
            ),
          ),
        ),

        // Calendar navigation controls
        CalendarControls(
          selectedDay: _selectedDay,
          viewType: _viewType,
          onPrevious: _navigatePrevious,
          onNext: _navigateNext,
          onDatePickerTap: () => _showDatePicker(context),
        ),

        // Calendar content
        Expanded(
          child: switch (_viewType) {
            CalendarViewType.month => MonthViewWidget(
              selectedDay: _selectedDay,
              onDaySelected: (d) {
                setState(() {
                  _selectedDay = d;
                  _viewType = CalendarViewType.day;
                });
              },
              onMonthChanged: (d) => setState(() => _selectedDay = d),
            ),
            CalendarViewType.week => WeekViewWidget(
              selectedDay: _selectedDay,
              onDaySelected: (d) {
                setState(() {
                  _selectedDay = d;
                  _viewType = CalendarViewType.day;
                });
              },
              onWeekChanged: (d) => setState(() => _selectedDay = d),
            ),
            _ => ClientDayViewWidget(
              selectedDay: _selectedDay,
              onRideSelected: widget.onRideSelected,
            ),
          },
        ),
      ],
    );
  }
}
