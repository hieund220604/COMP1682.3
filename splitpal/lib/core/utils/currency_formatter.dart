import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class CurrencyFormatter {
  /// Format VND currency with proper thousand separator
  /// Example: 1000000 -> "1.000.000 đ"
  static String formatVND(double amount) {
    final formatter = NumberFormat('#,##0', 'vi_VN');
    final formatted = formatter.format(amount.round());
    return '$formatted VND';
  }

  /// Format currency based on currency code
  static String formatCurrency(double amount, String currency) {
    if (currency.toUpperCase() == 'VND') {
      return formatVND(amount);
    }
    
    // For other currencies: show decimals only when they exist
    final hasDecimals = (amount % 1) != 0;
    final formatter = NumberFormat.currency(
      symbol: _getCurrencySymbol(currency),
      decimalDigits: hasDecimals ? 2 : 0,
    );
    return formatter.format(amount);
  }

  /// Compact format for large numbers
  /// Example: 1000000 -> "1M đ"
  static String formatVNDCompact(double amount) {
    if (amount >= 1000000000) {
      return '${(amount / 1000000000).toStringAsFixed(1)}B VND';
    } else if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M VND';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K VND';
    }
    return '${amount.round()} VND';
  }

  /// Format a raw integer as dot-separated string (e.g. 4000000 → "4.000.000")
  static String formatInput(int value) {
    final formatter = NumberFormat('#,###', 'vi_VN');
    return formatter.format(value).replaceAll(',', '.');
  }

  /// Parse a dot/comma-formatted string back to a double (e.g. "4.000.000" → 4000000.0)
  static double? parseFormatted(String text) {
    final clean = text.replaceAll(RegExp(r'[,.]'), '');
    if (clean.isEmpty) return null;
    return double.tryParse(clean);
  }

  static String _getCurrencySymbol(String currency) {
    switch (currency.toUpperCase()) {
      case 'VND':
        return 'VND';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      default:
        return currency;
    }
  }
}

/// TextInputFormatter that auto-inserts dot separators for VND amounts.
/// Use with [FilteringTextInputFormatter.digitsOnly] for best results.
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return newValue;

    final value = int.tryParse(digits);
    if (value == null) return oldValue;

    final formatted = CurrencyFormatter.formatInput(value);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
