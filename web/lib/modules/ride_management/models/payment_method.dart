import 'package:dispax/l10n/app_localizations.dart';

/// Payment method chosen for a ride.
///
/// Wire values match the backend `PaymentMethod` enum names exactly
/// ("Payment" | "Card" | "Invoice" | "Cash"). The default for new bookings is
/// [PaymentMethod.invoice] (Rechnung), the common case for business transfers.
enum PaymentMethod {
  payment('Payment'),
  creditCard('Card'),
  invoice('Invoice'),
  cash('Cash');

  const PaymentMethod(this.wire);

  /// Wire string sent to and received from the backend (matches the backend enum).
  final String wire;

  /// Resolve a wire string to a [PaymentMethod], or null when absent/unknown.
  /// The backend also has `Bank`/`Receivable` values that the UI does not offer
  /// for selection; those resolve to null and are simply not displayed.
  static PaymentMethod? fromWire(String? raw) {
    if (raw == null) return null;
    for (final m in PaymentMethod.values) {
      if (m.wire == raw) return m;
    }
    return null;
  }

  /// Localized label for this payment method.
  String label(AppLocalizations l10n) => switch (this) {
    PaymentMethod.payment => l10n.paymentMethodPayment,
    PaymentMethod.creditCard => l10n.paymentMethodCard,
    PaymentMethod.invoice => l10n.paymentMethodInvoice,
    PaymentMethod.cash => l10n.paymentMethodCash,
  };

  /// Localized label for a wire string, or null when it cannot be resolved.
  /// Convenience for display sites that hold the raw `Ride.paymentMethod` string.
  static String? labelForWire(String? wire, AppLocalizations l10n) =>
      fromWire(wire)?.label(l10n);
}
