import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'patrol_helpers.dart';

/// Regression: on the driver's Book (create-ride) screen, entering the "To"
/// address must NOT bounce focus back to the "Client Name" search field.
///
/// Root cause (fixed): AddressAutocompleteField used to rebuild its inner
/// Autocomplete via a ValueKey whenever initialValue changed. Any address edit
/// reran the location section's BlocBuilder, changed initialValue, recreated the
/// field and dropped focus — Flutter then moved focus to the first focusable
/// field, the client search at the top of the form. This test asserts focus
/// stays out of the client field after editing To.
void main() {
  patrolTest('entering To does not steal focus back to the client field', (
    $,
  ) async {
    await resetTestData();
    await bootstrapTestApp();
    await $.pumpAndSettle();

    await loginViaUi($, kDevDriver1, kDevPassword);
    if (skipIfBackendDown($)) return;

    await tapNav($, 'Book');
    await $.pumpAndSettle();

    // Field order for a driver: [0] client search, [1] From, [2] To.
    await $(TextFormField).at(1).enterText('Hauptbahnhof, München');
    await $.pumpAndSettle();
    await $(TextFormField).at(2).enterText('Marienplatz, München');
    await $.pumpAndSettle();

    // Locate the "Client Name" search field by its label.
    final clientField = find.ancestor(
      of: find.text('Client Name'),
      matching: find.byType(TextField),
    );
    expect(
      clientField,
      findsOneWidget,
      reason: 'Client search field should be present on the driver form',
    );

    // The bug: editing To recreated the address widget and bounced focus to the
    // client field. After the fix, the client field must NOT hold focus.
    final clientFocus =
        $.tester.widget<TextField>(clientField).focusNode?.hasFocus ?? false;
    expect(
      clientFocus,
      isFalse,
      reason:
          'Editing the To address must not steal focus to the client '
          'search field',
    );

    // And the global primary focus must not sit inside the client field.
    final primary = FocusManager.instance.primaryFocus;
    final clientContext = clientField.evaluate().single;
    final focusInsideClient =
        primary != null &&
        primary.context != null &&
        _isAncestorContext(clientContext, primary.context!);
    expect(
      focusInsideClient,
      isFalse,
      reason: 'Primary focus must not be inside the client search field',
    );
  });
}

/// True when [maybeAncestor] is an ancestor of (or equal to) [node]'s element.
bool _isAncestorContext(Element maybeAncestor, BuildContext node) {
  var found = false;
  node.visitAncestorElements((e) {
    if (e == maybeAncestor) {
      found = true;
      return false;
    }
    return true;
  });
  return found || node == maybeAncestor;
}
