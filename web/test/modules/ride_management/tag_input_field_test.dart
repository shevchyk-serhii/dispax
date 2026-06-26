import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/widgets/tag_input_field.dart';

void main() {
  Widget host({
    required List<String> tags,
    List<String> suggestions = const [],
    required void Function(String) onAdded,
    required void Function(String) onRemoved,
  }) => MaterialApp(
    home: Scaffold(
      body: TagInputField(
        tags: tags,
        suggestions: suggestions,
        onAdded: onAdded,
        onRemoved: onRemoved,
      ),
    ),
  );

  testWidgets('typing a tag and submitting calls onAdded with the text', (
    tester,
  ) async {
    String? added;
    await tester.pumpWidget(
      host(tags: const [], onAdded: (t) => added = t, onRemoved: (_) {}),
    );

    await tester.enterText(find.byType(TextField), 'Urgent');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(added, 'Urgent');
  });

  testWidgets('existing tags render as deletable chips and fire onRemoved', (
    tester,
  ) async {
    String? removed;
    await tester.pumpWidget(
      host(
        tags: const ['Cash'],
        onAdded: (_) {},
        onRemoved: (t) => removed = t,
      ),
    );

    expect(find.text('Cash'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();

    expect(removed, 'Cash');
  });

  testWidgets('tapping a suggestion chip adds it', (tester) async {
    String? added;
    await tester.pumpWidget(
      host(
        tags: const [],
        suggestions: const ['VIP'],
        onAdded: (t) => added = t,
        onRemoved: (_) {},
      ),
    );

    await tester.tap(find.text('VIP'));
    await tester.pump();

    expect(added, 'VIP');
  });

  testWidgets('already-selected suggestions are hidden', (tester) async {
    await tester.pumpWidget(
      host(
        tags: const ['VIP'],
        suggestions: const ['VIP', 'Cash'],
        onAdded: (_) {},
        onRemoved: (_) {},
      ),
    );

    // 'VIP' appears once (as the selected chip), not again as a suggestion.
    expect(find.text('VIP'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
  });
}
