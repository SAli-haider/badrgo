import 'package:intl/intl.dart';

/// Reusable utility to render multi-currency financial entries.
///
/// Requirement:
/// "revenue is a list with one entry per currency. Render it correctly."
class CurrencyFormatter {
  CurrencyFormatter._();

  static final NumberFormat _standardFormatter = NumberFormat('#,##0.00');
  static final NumberFormat _compactFormatter = NumberFormat.compact();

  /// Formats currency with its currency code/symbol.
  /// Example: format(12345.67, 'QAR') -> `QAR 12,345.67`
  static String format(num? amount, String? currency) {
    if (amount == null) return '0.00';
    final curr = currency?.toUpperCase().trim() ?? 'QAR';
    final formattedAmount = _standardFormatter.format(amount);
    return '$curr $formattedAmount';
  }

  /// Compact format for KPI tiles with large numbers.
  /// Example: formatCompact(1500000, 'QAR') -> `QAR 1.5M`
  static String formatCompact(num? amount, String? currency) {
    if (amount == null) return '0';
    final curr = currency?.toUpperCase().trim() ?? 'QAR';
    return '$curr ${_compactFormatter.format(amount)}';
  }
}
