import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Invoice Calculation Logic', () {
    test('Calculate Total with VAT and Discount', () {
      const double subtotal = 1000.0;
      const double vatPercent = 10.0; // 10%
      const double discount = 50.0;
      
      final double vatAmount = (subtotal * vatPercent) / 100;
      final double total = subtotal + vatAmount - discount;
      
      expect(vatAmount, 100.0);
      expect(total, 1050.0);
    });

    test('Calculate Due Amount correctly', () {
      const double totalAmount = 1050.0;
      const double paidAmount = 500.0;
      
      final double dueAmount = totalAmount - paidAmount;
      
      expect(dueAmount, 550.0);
    });

    test('Handle Zero VAT and No Discount', () {
      const double subtotal = 1000.0;
      const double vatPercent = 0.0;
      const double discount = 0.0;
      
      final double vatAmount = (subtotal * vatPercent) / 100;
      final double total = subtotal + vatAmount - discount;
      
      expect(vatAmount, 0.0);
      expect(total, 1000.0);
    });
  });
}
