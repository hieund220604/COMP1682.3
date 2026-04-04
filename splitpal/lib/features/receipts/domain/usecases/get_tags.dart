import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/receipt.dart';
import '../repositories/receipt_repository.dart';

class GetTags {
  final ReceiptRepository repository;
  GetTags(this.repository);

  Future<Either<Failure, List<ReceiptTag>>> call() {
    return repository.getTags();
  }
}
