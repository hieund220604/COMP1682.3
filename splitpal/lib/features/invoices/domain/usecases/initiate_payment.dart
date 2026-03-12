import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/invoice_repository.dart';

class InitiatePayment {
  final InvoiceRepository repository;

  InitiatePayment(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(String transferId, {String? totpToken}) async {
    return await repository.initiatePayment(transferId, totpToken: totpToken);
  }
}
