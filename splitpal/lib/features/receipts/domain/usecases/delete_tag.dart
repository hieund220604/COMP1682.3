import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/receipt_repository.dart';

class DeleteTag {
  final ReceiptRepository repository;
  DeleteTag(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteTag(id);
  }
}
