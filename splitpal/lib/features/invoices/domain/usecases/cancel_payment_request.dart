import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class CancelPaymentRequest {
  final InvoiceRepository repository;

  CancelPaymentRequest(this.repository);

  Future<Either<Failure, void>> call(String groupId, String requestId) async {
    return await repository.cancelPaymentRequest(groupId, requestId);
  }
}
