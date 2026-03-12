import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class CreatePaymentRequest {
  final InvoiceRepository repository;

  CreatePaymentRequest(this.repository);

  Future<Either<Failure, PaymentRequest>> call(String groupId) async {
    return await repository.createPaymentRequest(groupId);
  }
}
