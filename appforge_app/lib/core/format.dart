import '../models/models.dart';

/// Formats prices exactly like WooCommerce (symbol position, separators, decimals).
class Money {
  Money._();
  static Currency currency = const Currency();

  static String format(double value) {
    final c = currency;
    final fixed = value.abs().toStringAsFixed(c.decimals);
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => c.thousandSeparator);
    var number = parts.length > 1 ? '$intPart${c.decimalSeparator}${parts[1]}' : intPart;
    if (value < 0) number = '-$number';
    switch (c.position) {
      case 'right':
        return '$number${c.symbol}';
      case 'left_space':
        return '${c.symbol} $number';
      case 'right_space':
        return '$number ${c.symbol}';
      default:
        return '${c.symbol}$number';
    }
  }
}

String formatDate(String iso) {
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final l = d.toLocal();
  return '${l.day} ${months[l.month - 1]} ${l.year}';
}
