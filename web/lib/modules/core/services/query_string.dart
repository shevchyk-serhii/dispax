/// Builds a relative endpoint path with a properly encoded query string.
///
/// Services used to concatenate query parameters by hand
/// (`'/schedules?from=$from&to=$to'`), which breaks — or allows injecting
/// extra parameters — the moment a value contains a reserved character
/// (space, `&`, `=`, `#`, `+`). Today's values are URL-safe (ISO dates,
/// UUIDs, ints), so this is defense-in-depth: every value goes through
/// [Uri]'s query encoding (`Uri.encodeQueryComponent` semantics).
///
/// Null values are dropped, so optional parameters can be passed inline:
/// `withQuery('/billing/invoices', {'status': status?.value, ...})`.
/// An empty (or all-null) map returns [path] unchanged.
String withQuery(String path, Map<String, String?> params) {
  final present = <String, String>{
    for (final entry in params.entries)
      if (entry.value != null) entry.key: entry.value!,
  };
  if (present.isEmpty) return path;
  return '$path?${Uri(queryParameters: present).query}';
}
