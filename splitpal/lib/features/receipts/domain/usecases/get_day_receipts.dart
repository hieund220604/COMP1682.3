import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/receipt.dart';
import '../repositories/receipt_repository.dart';

class GetDayReceipts {
  final ReceiptRepository repository;
  GetDayReceipts(this.repository);

  Future<Either<Failure, List<Receipt>>> call(String date, {List<String>? tagIds}) {
    return repository.getDayReceipts(date, tagIds: tagIds);
  }
}
