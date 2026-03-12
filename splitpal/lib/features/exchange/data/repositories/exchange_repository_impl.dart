import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/exchange_rate.dart';
import '../../domain/repositories/exchange_repository.dart';
import '../datasources/exchange_remote_datasource.dart';

class ExchangeRepositoryImpl implements ExchangeRepository {
  final ExchangeRemoteDataSource remoteDataSource;

  ExchangeRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, ConversionResult>> convert({
    required String from,
    required String to,
    required double amount,
  }) async {
    try {
      final result = await remoteDataSource.convert(
        from: from,
        to: to,
        amount: amount,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ExchangeRate>> getRate({
    required String from,
    required String to,
  }) async {
    try {
      final result = await remoteDataSource.getRate(from: from, to: to);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getSupportedCurrencies() async {
    try {
      final result = await remoteDataSource.getSupportedCurrencies();
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
