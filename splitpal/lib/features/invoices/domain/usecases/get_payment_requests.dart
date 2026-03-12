import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class GetPaymentRequests {
  final InvoiceRepository repository;

  GetPaymentRequests(this.repository);

  Future<Either<Failure, List<PaymentRequest>>> call(String groupId) async {
    return await repository.getPaymentRequests(groupId);
  }
}
