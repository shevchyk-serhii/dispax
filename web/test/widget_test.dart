

import 'package:flutter_test/flutter_test.dart';

import 'package:oktopus/main.dart';

void main() {
  testWidgets('App starts with login screen', (WidgetTester tester) async {

    await tester.pumpWidget(const MyApp());

    expect(find.text('Oktopus Taxi'), findsOneWidget);
    expect(find.text('Professional Ride Management'), findsOneWidget);
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
