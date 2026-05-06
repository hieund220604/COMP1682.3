import 'package:flutter/foundation.dart';

import '../../core/network/dio_client.dart';
import '../../core/utils/safe_parse.dart';

// Inline data classes (too small for separate model files)
class ExchangeRate {
  final String from;
  final String to;
  final double rate;
  ExchangeRate({required this.from, required this.to, required this.rate});
}

class ConversionResult {
  final String from;
  final String to;
  final double amount;
  final double convertedAmount;
  final double rate;
  ConversionResult({
    required this.from,
    required this.to,
    required this.amount,
    required this.convertedAmount,
    required this.rate,
  });
}

/// Fat Provider — calls DioClient directly for currency exchange.
class ExchangeProvider extends ChangeNotifier {
  final DioClient _dio;

  ExchangeProvider({required DioClient dio}) : _dio = dio;

  // ─── State ──────────────────────────────────────────────
  List<String> _currencies = [];
  ConversionResult? _lastConversion;
  bool _isLoading = false;
  String? _error;

  String _fromCurrency = 'USD';
  String _toCurrency = 'VND';
  double _amount = 1.0;

  List<String> get currencies => _currencies;
  ConversionResult? get lastConversion => _lastConversion;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get fromCurrency => _fromCurrency;
  String get toCurrency => _toCurrency;
  double get amount => _amount;

  set fromCurrency(String v) { _fromCurrency = v; notifyListeners(); }
  set toCurrency(String v) { _toCurrency = v; notifyListeners(); }
  set amount(double v) { _amount = v; notifyListeners(); }

  void swapCurrencies() {
    final temp = _fromCurrency;
    _fromCurrency = _toCurrency;
    _toCurrency = temp;
    if (_lastConversion != null) convert();
    notifyListeners();
  }

  // ─── Load Currencies ───────────────────────────────────
  Future<void> loadCurrencies() async {
    try {
      final resp = await _dio.get('/exchange/currencies');
      final data = resp.data['data'];
      if (data is List) {
        _currencies = data.map((c) => c.toString()).toList();
      } else if (data is Map && data['currencies'] is List) {
        _currencies = (data['currencies'] as List).map((c) => c.toString()).toList();
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  // ─── Convert ────────────────────────────────────────────
  Future<void> convert() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _dio.get('/exchange/convert', queryParameters: {
        'from': _fromCurrency,
        'to': _toCurrency,
        'amount': _amount,
      });
      final data = resp.data['data'];
      _lastConversion = ConversionResult(
        from: data['fromCurrency'] ?? _fromCurrency,
        to: data['toCurrency'] ?? _toCurrency,
        amount: _amount,
        convertedAmount: safeDouble(data['convertedAmount']),
        rate: safeDouble(data['rate']),
      );
      _error = null;
    } catch (e) {
      _error = e.toString();
      _lastConversion = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Quick convert utility (doesn't update UI state)
  Future<double?> quickConvert(String from, String to, double amount) async {
    try {
      final resp = await _dio.get('/exchange/convert', queryParameters: {
        'from': from,
        'to': to,
        'amount': amount,
      });
      return safeDouble(resp.data['data']['convertedAmount']);
    } catch (_) {
      return null;
    }
  }
}
