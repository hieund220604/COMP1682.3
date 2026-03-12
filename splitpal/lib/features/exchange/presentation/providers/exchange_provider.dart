import 'package:flutter/foundation.dart';
import '../../domain/entities/exchange_rate.dart';
import '../../domain/repositories/exchange_repository.dart';

class ExchangeProvider extends ChangeNotifier {
  final ExchangeRepository repository;

  ExchangeProvider({required this.repository});

  // State
  List<String> _currencies = [];
  ConversionResult? _lastConversion;
  bool _isLoading = false;
  String? _error;

  // Selected currencies
  String _fromCurrency = 'USD';
  String _toCurrency = 'VND';
  double _amount = 1.0;

  // Getters
  List<String> get currencies => _currencies;
  ConversionResult? get lastConversion => _lastConversion;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get fromCurrency => _fromCurrency;
  String get toCurrency => _toCurrency;
  double get amount => _amount;

  set fromCurrency(String value) {
    _fromCurrency = value;
    notifyListeners();
  }

  set toCurrency(String value) {
    _toCurrency = value;
    notifyListeners();
  }

  set amount(double value) {
    _amount = value;
    notifyListeners();
  }

  void swapCurrencies() {
    final temp = _fromCurrency;
    _fromCurrency = _toCurrency;
    _toCurrency = temp;
    if (_lastConversion != null) {
      convert();
    }
    notifyListeners();
  }

  Future<void> loadCurrencies() async {
    final result = await repository.getSupportedCurrencies();
    result.fold(
      (failure) => _error = failure.message,
      (currencies) {
        _currencies = currencies;
        _error = null;
      },
    );
    notifyListeners();
  }

  Future<void> convert() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await repository.convert(
      from: _fromCurrency,
      to: _toCurrency,
      amount: _amount,
    );

    result.fold(
      (failure) {
        _error = failure.message;
        _lastConversion = null;
      },
      (conversion) {
        _lastConversion = conversion;
        _error = null;
      },
    );

    _isLoading = false;
    notifyListeners();
  }

  /// Quick convert utility (doesn't update UI state)
  Future<double?> quickConvert(String from, String to, double amount) async {
    final result = await repository.convert(from: from, to: to, amount: amount);
    return result.fold(
      (failure) => null,
      (conversion) => conversion.convertedAmount,
    );
  }
}
