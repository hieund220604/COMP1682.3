import '../../../../core/network/dio_client.dart';
import '../../domain/entities/exchange_rate.dart';

abstract class ExchangeRemoteDataSource {
  Future<ConversionResult> convert({
    required String from,
    required String to,
    required double amount,
  });

  Future<ExchangeRate> getRate({
    required String from,
    required String to,
  });

  Future<List<String>> getSupportedCurrencies();
}

class ExchangeRemoteDataSourceImpl implements ExchangeRemoteDataSource {
  final DioClient dioClient;

  ExchangeRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<ConversionResult> convert({
    required String from,
    required String to,
    required double amount,
  }) async {
    final response = await dioClient.get(
      '/exchange/convert',
      queryParameters: {'from': from, 'to': to, 'amount': amount},
    );
    final data = response.data['data'];
    return ConversionResult(
      from: data['fromCurrency'] ?? from,
      to: data['toCurrency'] ?? to,
      amount: amount,
      convertedAmount: (data['convertedAmount'] ?? 0).toDouble(),
      rate: (data['rate'] ?? 0).toDouble(),
    );
  }

  @override
  Future<ExchangeRate> getRate({
    required String from,
    required String to,
  }) async {
    final response = await dioClient.get(
      '/exchange/rate',
      queryParameters: {'from': from, 'to': to},
    );
    final data = response.data['data'];
    return ExchangeRate(
      from: data['fromCurrency'] ?? from,
      to: data['toCurrency'] ?? to,
      rate: (data['rate'] ?? 0).toDouble(),
    );
  }

  @override
  Future<List<String>> getSupportedCurrencies() async {
    final response = await dioClient.get('/exchange/currencies');
    // Backend returns the array directly as data (not wrapped in {currencies: [...]})
    final data = response.data['data'];
    if (data is List) {
      return data.map((c) => c.toString()).toList();
    }
    // Fallback if wrapped in object
    final currencies = data['currencies'] as List;
    return currencies.map((c) => c.toString()).toList();
  }
}
