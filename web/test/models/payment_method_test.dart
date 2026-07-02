import 'package:flutter_test/flutter_test.dart';
import 'package:dispax/modules/ride_management/models/payment_method.dart';

void main() {
  group('PaymentMethod', () {
    test('wire values match the backend enum names', () {
      expect(PaymentMethod.payment.wire, 'Payment');
      expect(PaymentMethod.creditCard.wire, 'Card');
      expect(PaymentMethod.invoice.wire, 'Invoice');
      expect(PaymentMethod.cash.wire, 'Cash');
    });

    test('fromWire resolves every offered wire value', () {
      expect(PaymentMethod.fromWire('Payment'), PaymentMethod.payment);
      expect(PaymentMethod.fromWire('Card'), PaymentMethod.creditCard);
      expect(PaymentMethod.fromWire('Invoice'), PaymentMethod.invoice);
      expect(PaymentMethod.fromWire('Cash'), PaymentMethod.cash);
    });

    test('fromWire returns null for null input', () {
      expect(PaymentMethod.fromWire(null), isNull);
    });

    test('fromWire returns null for backend values not offered in the UI', () {
      // Bank / Receivable exist on the backend but are not selectable here.
      expect(PaymentMethod.fromWire('Bank'), isNull);
      expect(PaymentMethod.fromWire('Receivable'), isNull);
      expect(PaymentMethod.fromWire('Bitcoin'), isNull);
    });

    test('offers exactly the four requested methods', () {
      expect(PaymentMethod.values, [
        PaymentMethod.payment,
        PaymentMethod.creditCard,
        PaymentMethod.invoice,
        PaymentMethod.cash,
      ]);
    });
  });
}
