class ExchangeRate {
  final String from;
  final String to;
  final double rate;

  ExchangeRate({
    required this.from,
    required this.to,
    required this.rate,
  });
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
