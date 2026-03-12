import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/invoice_repository.dart';

class CancelTransfer {
  final InvoiceRepository repository;

  CancelTransfer(this.repository);

  Future<Either<Failure, void>> call(String transferId) async {
    return await repository.cancelTransfer(transferId);
  }
}
