import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class GetMyBalance {
  final InvoiceRepository repository;

  GetMyBalance(this.repository);

  Future<Either<Failure, MyBalance>> call(String groupId) async {
    return await repository.getMyBalance(groupId);
  }
}
