import '../../core/services/api_client.dart' show ScheduleConflictInfo;
import '../../../l10n/app_localizations.dart';

/// Builds the schedule-conflict dialog body. Prefers the structured details
/// from the backend (route + the conflicting ride's pickup time rendered in the
/// viewer's LOCAL time) so the dispatcher sees which ride conflicts; falls back
/// to the raw server message, then to a generic default.
///
/// [info] is the structured conflict (may be null for an unavailability
/// conflict or the create-self-assign path, where the backend swallows the
/// error and returns no details). [message] is the raw server error string.
String scheduleConflictDialogBody(
  AppLocalizations l10n, {
  ScheduleConflictInfo? info,
  String? message,
}) {
  final from = info?.from;
  final to = info?.to;
  if (info != null && from != null && to != null) {
    return l10n.conflictDialogContentRich(
      from,
      to,
      _formatLocalTime(info.pickupAt),
    );
  }
  if (message != null) return l10n.conflictDialogContent(message);
  return l10n.conflictDialogContentDefault;
}

/// Formats an ISO-8601 UTC instant from the backend into the viewer's local
/// time as `dd.MM HH:mm`. Returns a dash when absent or unparseable so the
/// dialog never shows a raw timestamp.
String _formatLocalTime(String? iso) {
  if (iso == null) return '—';
  final parsed = DateTime.tryParse(iso);
  if (parsed == null) return '—';
  final local = parsed.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
