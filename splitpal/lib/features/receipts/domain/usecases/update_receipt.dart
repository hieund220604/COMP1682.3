import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/receipt.dart';
import '../repositories/receipt_repository.dart';

class UpdateReceipt {
  final ReceiptRepository repository;
  UpdateReceipt(this.repository);

  Future<Either<Failure, Receipt>> call({
    required String id,
    String? note,
    List<String>? tagIds,
  }) {
    return repository.updateReceipt(
      id: id,
      note: note,
      tagIds: tagIds,
    );
  }
}
