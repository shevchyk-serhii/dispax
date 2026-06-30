import '../../../l10n/app_localizations.dart';
import 'api_client.dart';

/// Single source of truth for turning any caught error into a short, localized,
/// user-facing message.
///
/// The rule this enforces (see the error-UX plan): the UI never shows a raw
/// exception. Blocs and screens that catch an error pass the error object here
/// together with the active [AppLocalizations]; this function classifies it via
/// [ApiException.kind] and returns text safe to put in a SnackBar, banner, or
/// [ErrorDisplayWidget].
///
/// The result is always a clean, non-technical sentence — it never leaks the
/// backend URL, the exception class name, an HTTP status code, or a stack-trace
/// tail, in any build. Developers who need the raw cause have it in the logs
/// (the ApiClient `debugPrint`s every failure) and on the exception itself; the
/// UI must stay clean, so a technical tail is opt-in only.
///
/// Set [includeDebugDetail] to append a `[debug]` technical tail — intended for
/// diagnostic surfaces, never for production UI. Defaults to `false`.
String friendlyError(
  Object? error,
  AppLocalizations l10n, {
  bool includeDebugDetail = false,
}) {
  final base = _baseMessage(error, l10n);
  if (includeDebugDetail && error != null) {
    final technical = _technicalDetail(error);
    if (technical != null && technical.isNotEmpty) {
      return '$base\n\n[debug] $technical';
    }
  }
  return base;
}

String _baseMessage(Object? error, AppLocalizations l10n) {
  if (error is UnauthorizedException) {
    return l10n.errorSessionExpired;
  }
  if (error is ApiException) {
    switch (error.kind) {
      case AppErrorKind.unauthorized:
        return l10n.errorSessionExpired;
      case AppErrorKind.timeout:
        return l10n.errorTimeout;
      case AppErrorKind.network:
        return l10n.errorNetwork;
      case AppErrorKind.server:
        return l10n.errorServer;
      case AppErrorKind.notFound:
        return l10n.errorNotFound;
      case AppErrorKind.validation:
      case AppErrorKind.conflict:
        // A 4xx/409 carries the backend's own human-readable reason (see
        // ApiException.fromResponse, which extracts `{"error": "..."}`). That
        // text is business-meaningful (e.g. "Pickup location cannot be empty"),
        // so surface it — but strip the internal "<action>: " prefix and never
        // fall back to a raw wrapped message.
        return _serverDetail(error.message) ?? l10n.errorGeneric;
      case AppErrorKind.unknown:
        return l10n.errorGeneric;
    }
  }
  return l10n.errorGeneric;
}

/// Extracts the backend's reason from an [ApiException.message] of the shape
/// `<action>: <detail>`, returning just the detail. Returns null when the
/// message looks like a wrapped/technical string (contains "ApiException", a
/// URL, or an exception class) so we don't leak internals as a "validation"
/// message.
String? _serverDetail(String message) {
  if (_looksTechnical(message)) return null;
  final idx = message.indexOf(': ');
  final detail = idx >= 0 ? message.substring(idx + 2).trim() : message.trim();
  if (detail.isEmpty || _looksTechnical(detail)) return null;
  return detail;
}

bool _looksTechnical(String s) {
  final lower = s.toLowerCase();
  return lower.contains('apiexception') ||
      lower.contains('exception:') ||
      lower.contains('http://') ||
      lower.contains('https://') ||
      lower.contains('/api/') ||
      lower.contains('future not completed');
}

String? _technicalDetail(Object error) {
  if (error is ApiException) {
    final cause = error.cause;
    return cause != null ? '${error.message} (cause: $cause)' : error.message;
  }
  return error.toString();
}
