import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/receipt.dart';
import '../repositories/receipt_repository.dart';

class CreateTag {
  final ReceiptRepository repository;
  CreateTag(this.repository);

  Future<Either<Failure, ReceiptTag>> call({
    required String name,
    required String color,
  }) {
    return repository.createTag(name: name, color: color);
  }
}
