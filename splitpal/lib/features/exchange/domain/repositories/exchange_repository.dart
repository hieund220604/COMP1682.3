import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/exchange_rate.dart';

abstract class ExchangeRepository {
  Future<Either<Failure, ConversionResult>> convert({
    required String from,
    required String to,
    required double amount,
  });

  Future<Either<Failure, ExchangeRate>> getRate({
    required String from,
    required String to,
  });

  Future<Either<Failure, List<String>>> getSupportedCurrencies();
}
