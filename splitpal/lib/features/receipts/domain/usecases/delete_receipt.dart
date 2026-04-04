import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/receipt_repository.dart';

class DeleteReceipt {
  final ReceiptRepository repository;
  DeleteReceipt(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteReceipt(id);
  }
}
