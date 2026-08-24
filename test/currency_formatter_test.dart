import 'package:flutter_test/flutter_test.dart';
import 'package:youdo/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter', () {
    test('formats currency with two decimal places', () {
      expect(CurrencyFormatter.format(12.5), r'$12.50');
    });

    test('omits decimals for compact whole-dollar amounts', () {
      expect(CurrencyFormatter.formatCompact(12), r'$12');
    });

    test('keeps decimals for compact fractional amounts', () {
      expect(CurrencyFormatter.formatCompact(12.5), r'$12.50');
    });
  });
}
