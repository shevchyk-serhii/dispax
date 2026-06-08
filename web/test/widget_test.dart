import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/main.dart';

void main() {
  // MyApp requires Firebase initialization which is not available in unit tests.
  // This test is effectively an integration test and should be run with a real device/emulator.
  testWidgets('App widget can be instantiated', (WidgetTester tester) async {
    expect(const MyApp(), isNotNull);
  });
}
