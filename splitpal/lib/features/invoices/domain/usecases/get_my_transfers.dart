import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class GetMyTransfers {
  final InvoiceRepository repository;

  GetMyTransfers(this.repository);

  Future<Either<Failure, List<Transfer>>> call(String groupId) async {
    return await repository.getMyTransfers(groupId);
  }
}
