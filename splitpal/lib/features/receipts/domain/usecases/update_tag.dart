import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/receipt.dart';
import '../repositories/receipt_repository.dart';

class UpdateTag {
  final ReceiptRepository repository;
  UpdateTag(this.repository);

  Future<Either<Failure, ReceiptTag>> call({
    required String id,
    String? name,
    String? color,
  }) {
    return repository.updateTag(id: id, name: name, color: color);
  }
}
