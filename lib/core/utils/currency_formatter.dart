import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final _formatter = NumberFormat.currency(
    symbol: '\$',
    decimalDigits: 2,
  );

  static String format(double amount) => _formatter.format(amount);

  static String formatCompact(double amount) {
    if (amount == amount.truncate()) {
      return '\$${amount.truncate()}';
    }
    return _formatter.format(amount);
  }
}
