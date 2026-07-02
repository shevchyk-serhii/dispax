// Pure-widget tests for the shared ClientAutocompleteField (extracted from
// ClientSearchField so the create-ride form and the edit-ride dialog use one
// picker). Locks the controlled contract: selection/clear flow through the
// callbacks, the check icon follows selectedClientId, and initialClientName
// pre-fills the search text.

import 'package:dispax/modules/core/models/person.dart';
import 'package:dispax/modules/core/services/api_client.dart';
import 'package:dispax/modules/core/services/user_service.dart';
import 'package:dispax/modules/ride_management/widgets/client_autocomplete_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/test_fixtures.dart';

class _MockUserService extends Mock implements UserService {}

class _MockApiClient extends Mock implements ApiClient {}

void main() {
  late _MockUserService userService;

  final clients = [
    TestFixtures.person(
      id: 'client-1',
      name: 'Anna Schmidt',
      email: 'anna@example.com',
    ),
    TestFixtures.person(
      id: 'client-2',
      name: 'Boris Weber',
      email: 'boris@example.com',
    ),
  ];

  setUp(() {
    userService = _MockUserService();
    when(() => userService.getClients()).thenAnswer((_) async => clients);
    when(() => userService.privateApiClient).thenReturn(_MockApiClient());
  });

  Widget host({
    String? selectedClientId,
    String? initialClientName,
    required ValueChanged<Person> onSelected,
    required VoidCallback onCleared,
  }) => MaterialApp(
    home: Scaffold(
      body: ClientAutocompleteField(
        userService: userService,
        selectedClientId: selectedClientId,
        initialClientName: initialClientName,
        onSelected: onSelected,
        onCleared: onCleared,
      ),
    ),
  );

  testWidgets('selecting an option calls onSelected with that person', (
    tester,
  ) async {
    Person? selected;
    await tester.pumpWidget(
      host(
        selectedClientId: null,
        onSelected: (p) => selected = p,
        onCleared: () {},
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'Boris');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Boris Weber').last);
    await tester.pumpAndSettle();

    expect(selected?.id, 'client-2');
  });

  testWidgets('the clear button calls onCleared', (tester) async {
    var cleared = false;
    await tester.pumpWidget(
      host(
        selectedClientId: 'client-1',
        initialClientName: 'Anna Schmidt',
        onSelected: (_) {},
        onCleared: () => cleared = true,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(cleared, isTrue);
  });

  testWidgets('a selection shows the check icon; none hides it', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        selectedClientId: 'client-1',
        initialClientName: 'Anna Schmidt',
        onSelected: (_) {},
        onCleared: () {},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await tester.pumpWidget(
      host(selectedClientId: null, onSelected: (_) {}, onCleared: () {}),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle), findsNothing);
  });

  testWidgets('initialClientName pre-fills the search field', (tester) async {
    await tester.pumpWidget(
      host(
        selectedClientId: 'client-1',
        initialClientName: 'Anna Schmidt',
        onSelected: (_) {},
        onCleared: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Anna Schmidt'), findsOneWidget);
  });
}
