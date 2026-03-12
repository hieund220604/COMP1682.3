import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class GetInvoices {
  final InvoiceRepository repository;

  GetInvoices(this.repository);

  Future<Either<Failure, List<Invoice>>> call(String groupId, {String? status}) async {
    return await repository.getInvoices(groupId, status: status);
  }
}
