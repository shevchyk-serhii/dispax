@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'patrol_helpers.dart';
import 'ride_flow_helpers.dart';

/// Expense amount validation: a negative or zero amount must be rejected (it
/// would otherwise flow into the DATEV export as a credit). Guards the amount
/// check in ExpenseRoutes POST /api/expenses.
void main() {
  late String driverToken;

  // Log in once to avoid tripping the /auth/login rate limiter across tests.
  setUpAll(() async {
    driverToken = await apiLogin(kDevDriver1, kDevPassword);
  });

  setUp(() async {
    await resetTestData();
  });

  test('rejects a negative expense amount', () async {
    final res = await createExpense(driverToken, amount: -100.50);
    expect(res.status, 400,
        reason: 'a negative amount must be 400, was ${res.status}');
  });

  test('rejects a zero expense amount', () async {
    final res = await createExpense(driverToken, amount: 0);
    expect(res.status, 400,
        reason: 'a zero amount must be 400, was ${res.status}');
  });

  test('accepts a positive expense amount', () async {
    final res = await createExpense(driverToken, amount: 42.50);
    expect(res.status, anyOf(200, 201),
        reason: 'a positive amount should succeed, was ${res.status}');
  });
}
