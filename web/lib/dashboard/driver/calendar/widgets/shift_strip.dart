import 'package:flutter/material.dart';
import '../../../../constants/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../modules/core/services/api_client.dart';
import '../../../../modules/core/services/error_messages.dart';
import '../../../../modules/schedule_management/models/schedule_day.dart';
import '../../../../modules/schedule_management/services/schedule_service.dart';

/// Compact strip above the calendar showing the selected driver's shifts for
/// the selected day, with a "+" chip to create new ones (single day or
/// repeated daily until a date) and tap-to-cancel on an existing shift.
///
/// This is the missing write-side of the work schedule: shifts created here
/// become visible to dispatchers (Driver Schedules / day board), to colleagues
/// via the schedule-visibility flag, and to other companies via calendar
/// shares.
class ShiftStrip extends StatefulWidget {
  /// Whose shifts to show/manage.
  final String driverId;

  final DateTime selectedDay;

  /// Whether the viewer may create/cancel shifts for [driverId] (self, or a
  /// dispatcher/admin managing a company driver).
  final bool canManage;

  final ScheduleService service;

  /// The driver's shifts (all days), loaded and owned by the parent screen so
  /// the calendar grid views can render the same data. The strip filters them
  /// to [selectedDay].
  final List<ScheduleDay> shifts;

  /// Invoked after a shift is created or cancelled so the owner can reload
  /// [shifts] (and any grid rendering derived from them).
  final Future<void> Function() onChanged;

  const ShiftStrip({
    super.key,
    required this.driverId,
    required this.selectedDay,
    required this.canManage,
    required this.service,
    required this.shifts,
    required this.onChanged,
  });

  @override
  State<ShiftStrip> createState() => _ShiftStripState();
}

class _ShiftStripState extends State<ShiftStrip> {
  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<ScheduleDay> get _dayShifts =>
      widget.shifts
          .where(
            (s) =>
                _sameDay(s.date, widget.selectedDay) &&
                s.status != ScheduleDayStatus.cancelled,
          )
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));

  /// Shift times come as "HH:mm[:ss]" strings — render the first 5 chars.
  static String _hhmm(String raw) =>
      raw.length >= 5 ? raw.substring(0, 5) : raw;

  static String _dateStr(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ── Create ──────────────────────────────────────────────────────────────────

  Future<void> _openCreateDialog() async {
    final l10n = AppLocalizations.of(context)!;
    final request = await showDialog<_CreateShiftRequest>(
      context: context,
      builder: (_) => _CreateShiftDialog(initialDate: widget.selectedDay),
    );
    if (request == null || !mounted) return;

    try {
      int created;
      if (request.repeatUntil == null) {
        await widget.service.createScheduleDay(
          driverId: widget.driverId,
          date: _dateStr(request.date),
          startTime: request.startTime,
          endTime: request.endTime,
          notes: request.note,
        );
        created = 1;
      } else {
        final days = <Map<String, dynamic>>[];
        var day = request.date;
        while (!day.isAfter(request.repeatUntil!)) {
          days.add({
            'date': _dateStr(day),
            'startTime': request.startTime,
            'endTime': request.endTime,
            if (request.note != null) 'notes': request.note,
          });
          day = day.add(const Duration(days: 1));
        }
        await widget.service.createBatch(driverId: widget.driverId, days: days);
        created = days.length;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.shiftsCreatedSnack(created))));
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      // A 409 means the requested time overlaps an existing (non-cancelled)
      // shift — say so in the user's language instead of the raw backend text
      // (which carries the driver UUID).
      final message = (e is ApiException && e.kind == AppErrorKind.conflict)
          ? l10n.shiftOverlapSnack
          : friendlyError(e, l10n);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: AppColors.error),
      );
    }
  }

  // ── Cancel ──────────────────────────────────────────────────────────────────

  Future<void> _confirmCancel(ScheduleDay shift) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.shiftCancelTitle),
        content: Text('${_hhmm(shift.startTime)}–${_hhmm(shift.endTime)}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(l10n.shiftCancelButton),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.service.cancelScheduleDay(shift.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.shiftCancelledSnack)));
      await widget.onChanged();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e, l10n)),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final shifts = _dayShifts;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (shifts.isEmpty)
                    Text(
                      l10n.noShiftsForDay,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...shifts.map(
                      (shift) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: InputChip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(
                            '${_hhmm(shift.startTime)}–${_hhmm(shift.endTime)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          avatar: Icon(
                            shift.status == ScheduleDayStatus.active
                                ? Icons.play_circle_outline
                                : Icons.event_available,
                            size: 15,
                          ),
                          onPressed: widget.canManage
                              ? () => _confirmCancel(shift)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.canManage)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20),
              tooltip: l10n.addShiftTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: _openCreateDialog,
            ),
        ],
      ),
    );
  }
}

class _CreateShiftRequest {
  final DateTime date;
  final String startTime;
  final String endTime;
  final DateTime? repeatUntil;
  final String? note;

  const _CreateShiftRequest({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.repeatUntil,
    this.note,
  });
}

/// Dialog collecting date, start/end time, optional daily repeat-until date
/// and an optional note. Validates start < end client-side; duplicate/overlap
/// conflicts surface from the backend as a 409.
class _CreateShiftDialog extends StatefulWidget {
  final DateTime initialDate;

  const _CreateShiftDialog({required this.initialDate});

  @override
  State<_CreateShiftDialog> createState() => _CreateShiftDialogState();
}

class _CreateShiftDialogState extends State<_CreateShiftDialog> {
  late DateTime _date;
  TimeOfDay _start = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 16, minute: 0);
  DateTime? _repeatUntil;
  final _noteController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  static String _timeStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        if (_repeatUntil != null && _repeatUntil!.isBefore(picked)) {
          _repeatUntil = null;
        }
      });
    }
  }

  Future<void> _pickRepeatUntil() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _repeatUntil ?? _date,
      firstDate: _date,
      // Batch endpoint creates one row per day — keep the range sane.
      lastDate: _date.add(const Duration(days: 31)),
    );
    setState(() => _repeatUntil = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _start = picked;
        } else {
          _end = picked;
        }
        _error = null;
      });
    }
  }

  void _submit() {
    final l10n = AppLocalizations.of(context)!;
    final startMinutes = _start.hour * 60 + _start.minute;
    final endMinutes = _end.hour * 60 + _end.minute;
    if (startMinutes >= endMinutes) {
      setState(() => _error = l10n.shiftTimeOrderError);
      return;
    }
    final note = _noteController.text.trim();
    Navigator.pop(
      context,
      _CreateShiftRequest(
        date: _date,
        startTime: _timeStr(_start),
        endTime: _timeStr(_end),
        repeatUntil: _repeatUntil,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final localizations = MaterialLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.addShiftTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today, size: 20),
              title: Text(l10n.shiftDateLabel),
              subtitle: Text(localizations.formatMediumDate(_date)),
              onTap: _pickDate,
            ),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.shiftStartLabel,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      _timeStr(_start),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _pickTime(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.shiftEndLabel,
                      style: const TextStyle(fontSize: 13),
                    ),
                    subtitle: Text(
                      _timeStr(_end),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.repeat, size: 20),
              title: Text(
                l10n.shiftRepeatUntilLabel,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                _repeatUntil == null
                    ? '—'
                    : localizations.formatMediumDate(_repeatUntil!),
              ),
              onTap: _pickRepeatUntil,
              trailing: _repeatUntil == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() => _repeatUntil = null),
                    ),
            ),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: l10n.shiftNoteLabel,
                isDense: true,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  _error!,
                  style: TextStyle(color: AppColors.error, fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.shiftCreateButton)),
      ],
    );
  }
}
