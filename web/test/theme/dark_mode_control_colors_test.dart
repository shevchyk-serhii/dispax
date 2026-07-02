// Regression guard for the dark-mode control-color sweep.
//
// Bug class: a control hardcodes a FOREGROUND color (text/icon/border/checkmark/
// active-thumb/selected-tint) to a graphite token — AppColors.primary or one of
// its aliases secretaryColor/driverColor/clientColor/dispatcherColor, all
// #18181B — which equals the dark `surfaceDark`. On the themed surface in dark
// mode the content collapses into the background and the control looks blank.
//
// The fix replaced these with theme-aware colors (colorScheme.primary /
// onSurfaceVariant / onPrimary). This test reads the affected source files and
// fails if any of those graphite tokens reappear as a foreground-style control
// color. `backgroundColor:` is intentionally NOT flagged — graphite-filled brand
// surfaces (with a white/onPrimary foreground) are legitimate and readable in
// both themes.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Files cleaned by the sweep. Paths are relative to the web/ package root.
  const auditedFiles = <String>[
    'lib/constants/app_styles.dart',
    'lib/dashboard/client/client_dashboard.dart',
    'lib/dashboard/dispatcher/widgets/assignment_dialog.dart',
    'lib/dashboard/dispatcher/widgets/bulk_reassign_dialog.dart',
    'lib/dashboard/secretary/widgets/client_detail_screen.dart',
    'lib/dashboard/secretary/widgets/client_list_panel.dart',
    'lib/modules/flight_management/widgets/airport_entry_timer.dart',
    'lib/modules/ride_management/widgets/address_autocomplete_field.dart',
    'lib/modules/ride_management/widgets/basic_info_card.dart',
    'lib/modules/ride_management/widgets/client_autocomplete_field.dart',
    'lib/modules/ride_management/widgets/client_search_field.dart',
    'lib/modules/ride_management/widgets/location_card.dart',
    'lib/modules/ride_management/widgets/schedule_card.dart',
    'lib/modules/ride_management/widgets/sections/create_ride_basic_info_section.dart',
    'lib/modules/ride_management/widgets/sections/create_ride_form_sections.dart',
    'lib/modules/ride_management/widgets/sections/create_ride_notes_section.dart',
    'lib/screens/client_map_screen.dart',
    'lib/screens/geofence_screen.dart',
    'lib/screens/ride_pool_screen.dart',
  ];

  // Graphite tokens that collapse into the dark surface.
  const graphite =
      r'(primary|secretaryColor|driverColor|clientColor|dispatcherColor)';

  // Foreground-style properties where graphite-on-dark-surface is invisible.
  // `backgroundColor` is excluded on purpose (filled brand surfaces are fine).
  final foregroundGraphite = RegExp(
    '(foregroundColor|checkmarkColor|activeThumbColor|iconColor|selectedColor)'
    ':\\s*AppColors\\.$graphite\\b',
  );
  // A bare `color: AppColors.<graphite>` — ambiguous: it's a foreground when it
  // tints an Icon/Text, but a legitimate filled background inside a
  // BoxDecoration/Container. We only flag the foreground case, detected by an
  // `Icon(` on the same or a recent preceding line.
  final bareColorGraphite = RegExp('color:\\s*AppColors\\.$graphite\\b');
  final iconOpen = RegExp(r'\bIcon\(');

  // Static legacy styles in app_styles.dart keep the graphite tokens on purpose
  // as a non-context fallback; widgets must use the *Of(context) factories
  // instead. The migration of call sites is what this guard protects, so the
  // legacy declarations themselves are out of scope.
  bool isLegacyStaticStyle(String rel, String line) =>
      rel.endsWith('app_styles.dart');

  test('audited controls do not hardcode graphite foreground colors '
      '(invisible in dark mode)', () {
    final offenders = <String>[];
    for (final rel in auditedFiles) {
      final file = File(rel);
      expect(
        file.existsSync(),
        isTrue,
        reason: 'audited file is missing: $rel (update the list if moved)',
      );
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (isLegacyStaticStyle(rel, line)) continue;

        var isOffender = foregroundGraphite.hasMatch(line);
        // For a bare `color:` graphite, only flag it when an `Icon(` appears
        // on this or one of the few preceding lines (an icon foreground),
        // never inside a BoxDecoration/Container background.
        if (!isOffender && bareColorGraphite.hasMatch(line)) {
          final from = i - 3 < 0 ? 0 : i - 3;
          final window = lines.sublist(from, i + 1).join('\n');
          if (iconOpen.hasMatch(window)) isOffender = true;
        }
        if (isOffender) {
          offenders.add('$rel:${i + 1}: ${line.trim()}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'These controls use a graphite token as a foreground color, which '
          'is invisible on the dark surface. Use Theme.of(context).colorScheme'
          '.primary / onSurfaceVariant / onPrimary instead:\n'
          '${offenders.join('\n')}',
    );
  });
}
