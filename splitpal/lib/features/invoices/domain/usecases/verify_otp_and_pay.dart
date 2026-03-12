import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class VerifyOTPAndPay {
  final InvoiceRepository repository;

  VerifyOTPAndPay(this.repository);

  Future<Either<Failure, Transfer>> call(String transferId, String otp) async {
    return await repository.verifyOTPAndPay(transferId, otp);
  }
}
