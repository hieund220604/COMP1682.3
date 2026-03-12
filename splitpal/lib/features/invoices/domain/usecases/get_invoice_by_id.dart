import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class GetInvoiceById {
  final InvoiceRepository repository;

  GetInvoiceById(this.repository);

  Future<Either<Failure, Invoice>> call(String groupId, String invoiceId) async {
    return await repository.getInvoiceById(groupId, invoiceId);
  }
}
