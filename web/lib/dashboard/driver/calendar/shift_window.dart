/// Pure helpers for clipping a work shift into the calendar's visible day
/// window (06:00–23:00 in both the week grid and the board day timeline).
///
/// Shared by [WeekViewWidget] and [DayTimeline]. Extracted because both used
/// to clamp start AND end independently and drop the region when
/// `end - start <= 0` — which silently swallowed any shift crossing midnight
/// (22:00–06:00: the end clamped to the window start → negative height), so
/// the driver looked unavailable all evening.
library;

/// Parses an "HH:mm[:ss]" time string into fractional hours (e.g. "14:30" →
/// 14.5). Malformed input degrades to 0.
double parseShiftHour(String raw) {
  final parts = raw.split(':');
  final hour = int.tryParse(parts[0]) ?? 0;
  final minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  return hour + minute / 60.0;
}

/// Clips a shift ([startHour], [endHour], fractional hours) into the visible
/// [windowStart]–[windowEnd] window and returns the segment to render, or
/// null when nothing of the shift is visible.
///
/// A shift whose end is before (or at midnight, `0`) its start crosses
/// midnight: its evening part runs to the end of the day, so the visible
/// segment is `start → windowEnd`. (The morning part belongs to the next
/// calendar day and is only rendered there if the data provides the shift on
/// that day.)
({double start, double end})? visibleShiftSegment(
  double startHour,
  double endHour, {
  double windowStart = 6,
  double windowEnd = 23,
}) {
  // end < start (incl. end == 0 for "…–00:00") → the shift crosses midnight;
  // the evening segment extends to the end of the day.
  final effectiveEnd = endHour < startHour ? 24.0 : endHour;
  final start = startHour.clamp(windowStart, windowEnd);
  final end = effectiveEnd.clamp(windowStart, windowEnd);
  if (end - start <= 0) return null;
  return (start: start, end: end);
}

/// Clips an occupied block (a ride or a busy slot, fractional hours) into the
/// visible [windowStart]–[windowEnd] window, with the same midnight handling
/// as [visibleShiftSegment]: an end before its start (a 22:00→00:30 busy slot)
/// crosses midnight, so the visible part is the evening segment — NOT a
/// `bottom < top` rectangle that renderers used to collapse into a 10 px stub.
///
/// Unlike a shift region, a block is never dropped: when it lies entirely
/// outside the window (a 02:00 ride) a zero-length segment pinned at the
/// nearest window edge is returned, so renderers can draw their
/// minimum-height marker INSIDE the grid instead of positioning the block at
/// a negative offset above it.
({double start, double end}) visibleBlockSegment(
  double startHour,
  double endHour, {
  double windowStart = 6,
  double windowEnd = 23,
}) {
  final effectiveEnd = endHour < startHour ? 24.0 : endHour;
  final start = startHour.clamp(windowStart, windowEnd);
  final end = effectiveEnd.clamp(windowStart, windowEnd);
  if (end - start > 0) return (start: start, end: end);
  // Entirely outside the window: pin at the nearest edge (start already
  // clamped there) so the block stays discoverable inside the grid.
  return (start: start, end: start);
}
