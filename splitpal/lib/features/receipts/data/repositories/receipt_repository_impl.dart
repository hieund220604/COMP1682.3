import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/receipt.dart';
import '../../domain/repositories/receipt_repository.dart';
import '../datasources/receipt_remote_datasource.dart';

class ReceiptRepositoryImpl implements ReceiptRepository {
  final ReceiptRemoteDataSource remoteDataSource;

  ReceiptRepositoryImpl({required this.remoteDataSource});

  Failure _mapError(dynamic e) {
    if (e is ServerException) {
      return ServerFailure(message: e.message, statusCode: e.statusCode);
    }
    if (e is DioException) {
      return ServerFailure(message: e.message ?? 'Network error', statusCode: e.response?.statusCode);
    }
    return UnknownFailure(message: e.toString());
  }

  @override
  Future<Either<Failure, Receipt>> createReceipt({
    required String imageUrl,
    required DateTime receiptDate,
    String? note,
    required List<String> tagIds,
  }) async {
    try {
      final result = await remoteDataSource.createReceipt(
        imageUrl: imageUrl,
        receiptDate: receiptDate,
        note: note,
        tagIds: tagIds,
      );
      return Right(result);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteReceipt(String id) async {
    try {
      await remoteDataSource.deleteReceipt(id);
      return const Right(null);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, List<Receipt>>> getDayReceipts(String date, {List<String>? tagIds}) async {
    try {
      final data = await remoteDataSource.getDayReceipts(date, tagIds: tagIds);
      return Right(data);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptDaySummary>>> getMonthSummary(String month) async {
    try {
      final data = await remoteDataSource.getMonthSummary(month);
      return Right(data);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, Receipt>> updateReceipt({required String id, String? note, List<String>? tagIds}) async {
    try {
      final data = await remoteDataSource.updateReceipt(id: id, note: note, tagIds: tagIds);
      return Right(data);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, ReceiptTag>> createTag({required String name, required String color}) async {
    try {
      final data = await remoteDataSource.createTag(name: name, color: color);
      return Right(data);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, void>> deleteTag(String id) async {
    try {
      await remoteDataSource.deleteTag(id);
      return const Right(null);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, List<ReceiptTag>>> getTags() async {
    try {
      final data = await remoteDataSource.getTags();
      return Right(data);
    } catch (e) {
      return Left(_mapError(e));
    }
  }

  @override
  Future<Either<Failure, ReceiptTag>> updateTag({required String id, String? name, String? color}) async {
    try {
      final data = await remoteDataSource.updateTag(id: id, name: name, color: color);
      return Right(data);
    } catch (e) {
      return Left(_mapError(e));
    }
  }
}
