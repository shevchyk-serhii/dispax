// Tests that the billing l10n keys (added in the l10n-billing refactor) resolve
// to the correct strings in all three supported locales, and that parameterized
// keys format their placeholders correctly.
//
// This covers:
//   - Empty-state key semantics (noInvoices/noCompanies/noBillableRides/noExpenses
//     are distinct and map to the correct screen context)
//   - Parameterized key formatting across en/de/uk
//   - Key-for-key parity (all new billing keys exist in all three locales)
//
// The tests use AppLocalizations.delegate directly (no widget pump needed) so
// they are fast pure-Dart tests.

import 'package:dispax/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppLocalizations> _l10n(String languageCode) async {
  final locale = Locale(languageCode);
  return AppLocalizations.delegate.load(locale);
}

void main() {
  group('billing l10n keys — semantic correctness', () {
    test('empty-state keys are distinct and correct in German', () async {
      final de = await _l10n('de');
      expect(de.noInvoices, equals('Keine Rechnungen'));
      expect(de.noCompanies, equals('Keine Unternehmen'));
      expect(de.noBillableRides, equals('Keine abrechenbaren Fahrten'));
      expect(de.noExpenses, equals('Keine Ausgaben'));
      // Verify they are all distinct — a mix-up of keys would cause duplicates.
      final values = {
        de.noInvoices,
        de.noCompanies,
        de.noBillableRides,
        de.noExpenses,
      };
      expect(values.length, equals(4), reason: 'all four empty-state keys must be distinct strings in DE');
    });

    test('empty-state keys are distinct and correct in English', () async {
      final en = await _l10n('en');
      expect(en.noInvoices, equals('No Invoices'));
      expect(en.noCompanies, equals('No Companies'));
      expect(en.noBillableRides, equals('No billable rides'));
      expect(en.noExpenses, equals('No Expenses'));
      final values = {en.noInvoices, en.noCompanies, en.noBillableRides, en.noExpenses};
      expect(values.length, equals(4), reason: 'all four empty-state keys must be distinct strings in EN');
    });

    test('empty-state keys are distinct and correct in Ukrainian', () async {
      final uk = await _l10n('uk');
      expect(uk.noInvoices, equals('Немає рахунків'));
      expect(uk.noCompanies, equals('Немає компаній'));
      expect(uk.noBillableRides, equals('Немає поїздок для виставлення рахунку'));
      expect(uk.noExpenses, equals('Немає витрат'));
      final values = {uk.noInvoices, uk.noCompanies, uk.noBillableRides, uk.noExpenses};
      expect(values.length, equals(4), reason: 'all four empty-state keys must be distinct strings in UK');
    });
  });

  group('billing l10n keys — parameterized formatting', () {
    test('invoicesCountSubtitle formats month and count in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.invoicesCountSubtitle('Jan 2026', 5), equals('Jan 2026 · 5 Rechnungen'));
      expect(en.invoicesCountSubtitle('Jan 2026', 5), equals('Jan 2026 · 5 Invoices'));
      expect(uk.invoicesCountSubtitle('Jan 2026', 5), equals('Jan 2026 · 5 Рахунків'));
    });

    test('genericError formats error string in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.genericError('timeout'), equals('Fehler: timeout'));
      expect(en.genericError('timeout'), equals('Error: timeout'));
      expect(uk.genericError('timeout'), equals('Помилка: timeout'));
    });

    test('reminderBadgeLabel formats date in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.reminderBadgeLabel('05.03.2026'), equals('Erinnert 05.03.2026'));
      expect(en.reminderBadgeLabel('05.03.2026'), equals('Reminded 05.03.2026'));
      expect(uk.reminderBadgeLabel('05.03.2026'), equals('Нагадано 05.03.2026'));
    });

    test('totalLabel formats currency in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.totalLabel('EUR'), equals('Gesamt (EUR)'));
      expect(en.totalLabel('EUR'), equals('Total (EUR)'));
      expect(uk.totalLabel('EUR'), equals('Разом (EUR)'));
    });

    test('totalExpensesLabel is distinct from totalLabel in all locales', () async {
      // totalExpensesLabel is the expense footer ("Gesamt" / "Total" / "Всього")
      // totalLabel is the parameterized invoice total "Gesamt (EUR)" etc.
      // They must not be swapped.
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.totalExpensesLabel, equals('Gesamt'));
      expect(de.totalLabel('EUR'), contains('EUR')); // parameterized, must include currency
      expect(en.totalExpensesLabel, equals('Total'));
      expect(en.totalLabel('EUR'), contains('EUR'));
      expect(uk.totalExpensesLabel, equals('Всього'));
      expect(uk.totalLabel('EUR'), contains('EUR'));
    });

    test('deleteCompanyConfirmMsg formats name in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.deleteCompanyConfirmMsg('Acme GmbH'), equals('Acme GmbH wird gelöscht.'));
      expect(en.deleteCompanyConfirmMsg('Acme GmbH'), equals('Acme GmbH will be deleted.'));
      expect(uk.deleteCompanyConfirmMsg('Acme GmbH'), equals('Acme GmbH буде видалено.'));
    });

    test('expensesScreenTitle formats monthLabel in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.expensesScreenTitle('Jun 2026'), equals('Ausgaben · Jun 2026'));
      expect(en.expensesScreenTitle('Jun 2026'), equals('Expenses · Jun 2026'));
      expect(uk.expensesScreenTitle('Jun 2026'), equals('Витрати · Jun 2026'));
    });

    test('invoiceCreatedMsg formats number, count and amount in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.invoiceCreatedMsg('INV-001', 3, '357.00'),
          equals('INV-001 · 3 Fahrten · €357.00'));
      expect(en.invoiceCreatedMsg('INV-001', 3, '357.00'),
          equals('INV-001 · 3 rides · €357.00'));
      expect(uk.invoiceCreatedMsg('INV-001', 3, '357.00'),
          equals('INV-001 · 3 поїздок · €357.00'));
    });

    test('noDataForMonth formats monthLabel in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.noDataForMonth('März 2026'), equals('Keine Daten für März 2026'));
      expect(en.noDataForMonth('March 2026'), equals('No data for March 2026'));
      expect(uk.noDataForMonth('Березень 2026'), equals('Немає даних за Березень 2026'));
    });

    test('deleteExpenseConfirmMsg formats category and amount in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.deleteExpenseConfirmMsg('Kraftstoff', '48.50'),
          equals('Kraftstoff · €48.50 wird gelöscht.'));
      expect(en.deleteExpenseConfirmMsg('Fuel', '48.50'),
          equals('Fuel · €48.50 will be deleted.'));
      expect(uk.deleteExpenseConfirmMsg('Паливо', '48.50'),
          equals('Паливо · €48.50 буде видалено.'));
    });

    test('ridesBillingCountSelected and ridesBillingCountAvailable are distinct', () async {
      final de = await _l10n('de');
      // selected = "{count} ausgewählt", available = "{count} Fahrten"
      expect(de.ridesBillingCountSelected(3), equals('3 ausgewählt'));
      expect(de.ridesBillingCountAvailable(10), equals('10 Fahrten'));
      expect(de.ridesBillingCountSelected(3), isNot(equals(de.ridesBillingCountAvailable(3))));
    });
  });

  group('billing l10n keys — static string values', () {
    test('billingScreenTitle is correct in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      expect(de.billingScreenTitle, equals('Billing'));
      expect(en.billingScreenTitle, equals('Billing'));
      expect(uk.billingScreenTitle, equals('Білінг'));
    });

    test('tab labels are correct in German', () async {
      final de = await _l10n('de');
      expect(de.invoicesTab, equals('Rechnungen'));
      expect(de.companiesTab, equals('Unternehmen'));
      expect(de.billingRidesTab, equals('Fahrten'));
    });

    test('datev keys include DATEV brand in all locales', () async {
      final de = await _l10n('de');
      final en = await _l10n('en');
      final uk = await _l10n('uk');
      // DATEV is a brand name — must be preserved in all locales
      expect(de.exportDatevButton, contains('DATEV'));
      expect(en.exportDatevButton, contains('DATEV'));
      expect(uk.exportDatevButton, contains('DATEV'));
      expect(de.datevExportTitle, contains('DATEV'));
      expect(en.datevExportTitle, contains('DATEV'));
    });
  });
}
