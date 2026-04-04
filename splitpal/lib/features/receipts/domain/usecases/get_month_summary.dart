import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/receipt.dart';
import '../repositories/receipt_repository.dart';

class GetMonthSummary {
  final ReceiptRepository repository;
  GetMonthSummary(this.repository);

  Future<Either<Failure, List<ReceiptDaySummary>>> call(String month) {
    return repository.getMonthSummary(month);
  }
}
