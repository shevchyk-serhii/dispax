import 'package:flutter/material.dart';
import '../../../constants/app_colors.dart';
import '../../../constants/app_dimensions.dart';
import '../../../l10n/app_localizations.dart';
import '../../../modules/core/services/error_messages.dart';
import '../../../modules/schedule_management/models/calendar_share.dart';
import '../../../modules/schedule_management/services/calendar_share_service.dart';

/// Read-only week-paged agenda of a calendar shared from another company:
/// shift chips + busy bars only (the backend strips all ride/client details).
/// Deliberately NOT the regular calendar widgets — busy slots are not Rides
/// and must not look tappable or imply details we do not have.
class SharedCalendarView extends StatefulWidget {
  final String grantId;
  final String grantorName;
  final String grantorCompanyName;
  final CalendarShareService service;

  const SharedCalendarView({
    super.key,
    required this.grantId,
    required this.grantorName,
    required this.grantorCompanyName,
    required this.service,
  });

  @override
  State<SharedCalendarView> createState() => _SharedCalendarViewState();
}

class _SharedCalendarViewState extends State<SharedCalendarView> {
  late DateTime _weekStart;
  SharedCalendar? _calendar;
  bool _loading = true;
  Object? _error;

  /// Guards against out-of-order responses when paging weeks quickly.
  int _requestSeq = 0;

  @override
  void initState() {
    super.initState();
    _weekStart = _mondayOf(DateTime.now());
    _load();
  }

  @override
  void didUpdateWidget(covariant SharedCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.grantId != widget.grantId) {
      _weekStart = _mondayOf(DateTime.now());
      _load();
    }
  }

  static DateTime _mondayOf(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  Future<void> _load() async {
    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final calendar = await widget.service.getSharedCalendar(
        widget.grantId,
        from: _weekStart,
        to: _weekStart.add(const Duration(days: 6)),
      );
      if (mounted && seq == _requestSeq) {
        setState(() {
          _calendar = calendar;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted && seq == _requestSeq) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  void _changeWeek(int deltaDays) {
    setState(() => _weekStart = _weekStart.add(Duration(days: deltaDays)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildWeekSwitcher(context),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingMedium,
          ),
          child: Text(
            l10n.sharedCalendarTimesHint(widget.grantorCompanyName),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(child: _buildBody(context)),
      ],
    );
  }

  Widget _buildWeekSwitcher(BuildContext context) {
    final weekEnd = _weekStart.add(const Duration(days: 6));
    final localizations = MaterialLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingSmall,
        vertical: 4,
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeWeek(-7),
          ),
          Expanded(
            child: Text(
              '${localizations.formatShortDate(_weekStart)} – ${localizations.formatShortDate(weekEnd)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeWeek(7),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              friendlyError(_error, l10n),
              style: TextStyle(color: AppColors.error, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: _load, child: Text(l10n.retry)),
          ],
        ),
      );
    }
    final calendar = _calendar;
    if (calendar == null ||
        (calendar.shifts.isEmpty && calendar.busySlots.isEmpty)) {
      return Center(
        child: Text(
          l10n.sharedCalendarEmptyWeek,
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    return ListView(
      padding: const EdgeInsets.all(AppDimensions.paddingMedium),
      children: [
        for (final day in days) ..._buildDaySection(context, calendar, day),
      ],
    );
  }

  List<Widget> _buildDaySection(
    BuildContext context,
    SharedCalendar calendar,
    DateTime day,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final shifts = calendar.shifts
        .where(
          (s) =>
              s.date.year == day.year &&
              s.date.month == day.month &&
              s.date.day == day.day,
        )
        .toList();
    final slots =
        calendar.busySlots
            .where(
              (b) =>
                  b.start.year == day.year &&
                  b.start.month == day.month &&
                  b.start.day == day.day,
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    if (shifts.isEmpty && slots.isEmpty) return const [];

    final localizations = MaterialLocalizations.of(context);
    String time(DateTime t) =>
        localizations.formatTimeOfDay(TimeOfDay.fromDateTime(t));

    return [
      Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Text(
          localizations.formatMediumDate(day),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ),
      for (final shift in shifts)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${l10n.sharedCalendarShift} ${_hhmm(shift.startTime)}–${_hhmm(shift.endTime)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                shift.status,
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      for (final slot in slots)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                slot.kind == 'Unavailability'
                    ? Icons.do_not_disturb_on_outlined
                    : Icons.local_taxi,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                '${l10n.sharedCalendarBusy} ${time(slot.start)}–${time(slot.end)}',
                style: const TextStyle(fontSize: 12.5),
              ),
            ],
          ),
        ),
    ];
  }

  /// Shift times come as "HH:mm[:ss]" strings in the grantor company's local
  /// convention — render the first 5 chars, never convert timezones.
  static String _hhmm(String raw) =>
      raw.length >= 5 ? raw.substring(0, 5) : raw;
}
