import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/receipt.dart';
import '../repositories/receipt_repository.dart';

class CreateReceipt {
  final ReceiptRepository repository;
  CreateReceipt(this.repository);

  Future<Either<Failure, Receipt>> call({
    required String imageUrl,
    required DateTime receiptDate,
    String? note,
    required List<String> tagIds,
  }) {
    return repository.createReceipt(
      imageUrl: imageUrl,
      receiptDate: receiptDate,
      note: note,
      tagIds: tagIds,
    );
  }
}
