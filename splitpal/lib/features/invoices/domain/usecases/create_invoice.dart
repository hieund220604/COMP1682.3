import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';
import '../repositories/invoice_repository.dart';

class CreateInvoice {
  final InvoiceRepository repository;

  CreateInvoice(this.repository);

  Future<Either<Failure, Invoice>> call({
    required String groupId,
    required String title,
    required double amountTotal,
    required List<InvoiceItemCreate> items,
    String? imageUrl,
    String? note,
    String? currency,
  }) async {
    return await repository.createInvoice(
      groupId: groupId,
      title: title,
      amountTotal: amountTotal,
      items: items,
      imageUrl: imageUrl,
      note: note,
      currency: currency,
    );
  }
}
