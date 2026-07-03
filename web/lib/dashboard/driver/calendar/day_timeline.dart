import 'package:flutter/material.dart';

import '../../../constants/app_colors.dart';
import '../../../l10n/app_localizations.dart';

/// A shift rendered as a stretched translucent green "available" region on the
/// day timeline.
class TimelineShiftRegion {
  final String keyValue;

  /// "HH:mm[:ss]" strings in the owner's local convention.
  final String startTime;
  final String endTime;

  const TimelineShiftRegion({
    required this.keyValue,
    required this.startTime,
    required this.endTime,
  });
}

/// An occupied interval on the day timeline (a ride or a busy slot), rendered
/// as a bordered block on top of the availability regions.
class TimelineBlock {
  final String keyValue;
  final double startHour;
  final double endHour;
  final Color color;
  final Color borderColor;
  final Widget content;
  final VoidCallback? onTap;

  const TimelineBlock({
    required this.keyValue,
    required this.startHour,
    required this.endHour,
    required this.color,
    required this.borderColor,
    required this.content,
    this.onTap,
  });
}

/// Vertical day timeline (06:00–23:00) shared by the board columns and the
/// calendar day view. Shifts stretch as translucent green "available" regions
/// across the full hour range they cover; occupied blocks (rides / busy slots)
/// lie on top, so the free gaps inside a shift are visible at a glance. A slim
/// hour scale sits on the left.
class DayTimeline extends StatelessWidget {
  final List<TimelineShiftRegion> shiftRegions;
  final List<TimelineBlock> blocks;

  const DayTimeline({
    super.key,
    required this.shiftRegions,
    required this.blocks,
  });

  /// Visible day window, matching the week view: 06:00 → 23:00.
  static const double _startHour = 6;
  static const double _endHour = 23;
  static const double _hoursShown = _endHour - _startHour;

  /// Width of the left hour-scale gutter.
  static const double _gutterWidth = 30;

  static double _parseHhmm(String raw) {
    final parts = raw.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return hour + minute / 60.0;
  }

  static String _hhmm(String raw) =>
      raw.length >= 5 ? raw.substring(0, 5) : raw;

  double _offsetFor(double hourValue, double height) =>
      ((hourValue - _startHour).clamp(0.0, _hoursShown)) / _hoursShown * height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 6, 6, 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final height = constraints.maxHeight;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hour scale gutter: a label every 2 hours.
              SizedBox(
                width: _gutterWidth,
                child: Stack(
                  children: [
                    for (
                      var hour = _startHour.toInt();
                      hour <= _endHour.toInt();
                      hour += 2
                    )
                      Positioned(
                        top: _offsetFor(hour.toDouble(), height) - 5,
                        right: 4,
                        child: Text(
                          hour.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 9,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    // Hour gridlines every 2 hours.
                    for (
                      var hour = _startHour.toInt();
                      hour <= _endHour.toInt();
                      hour += 2
                    )
                      Positioned(
                        top: _offsetFor(hour.toDouble(), height),
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 1,
                          color: colorScheme.surfaceContainerHighest,
                        ),
                      ),
                    // Availability regions: each shift stretches over its full
                    // time range.
                    for (final region in shiftRegions)
                      _buildShiftRegion(context, l10n, region, height),
                    // Occupied blocks on top of the availability regions.
                    for (final block in blocks) _buildBlock(block, height),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShiftRegion(
    BuildContext context,
    AppLocalizations l10n,
    TimelineShiftRegion region,
    double height,
  ) {
    final top = _offsetFor(_parseHhmm(region.startTime), height);
    final bottom = _offsetFor(_parseHhmm(region.endTime), height);
    final regionHeight = bottom - top;
    if (regionHeight <= 0) return const SizedBox.shrink();

    return Positioned(
      key: ValueKey(region.keyValue),
      top: top,
      left: 0,
      right: 0,
      height: regionHeight,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border(left: BorderSide(color: AppColors.success, width: 3)),
        ),
        padding: const EdgeInsets.only(left: 6, top: 3),
        alignment: Alignment.topLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_hhmm(region.startTime)}–${_hhmm(region.endTime)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
            if (regionHeight > 44)
              Text(
                l10n.sharedCalendarAvailable,
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.success.withValues(alpha: 0.85),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlock(TimelineBlock block, double height) {
    final top = _offsetFor(block.startHour, height);
    final bottom = _offsetFor(block.endHour, height);
    // Keep even very short blocks visible.
    final blockHeight = (bottom - top).clamp(10.0, height);

    return Positioned(
      key: ValueKey(block.keyValue),
      top: top,
      left: 6,
      right: 2,
      height: blockHeight,
      child: GestureDetector(
        onTap: block.onTap,
        child: Container(
          decoration: BoxDecoration(
            color: block.color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: block.borderColor),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          alignment: Alignment.topLeft,
          child: blockHeight < 16 ? null : block.content,
        ),
      ),
    );
  }
}
