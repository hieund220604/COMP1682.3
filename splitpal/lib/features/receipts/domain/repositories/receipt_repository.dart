import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/receipt.dart';

abstract class ReceiptRepository {
  Future<Either<Failure, List<ReceiptDaySummary>>> getMonthSummary(String month); // month: YYYY-MM
  Future<Either<Failure, List<Receipt>>> getDayReceipts(String date, {List<String>? tagIds}); // date: YYYY-MM-DD
  Future<Either<Failure, Receipt>> createReceipt({
    required String imageUrl,
    required DateTime receiptDate,
    String? note,
    required List<String> tagIds,
  });
  Future<Either<Failure, Receipt>> updateReceipt({
    required String id,
    String? note,
    List<String>? tagIds,
  });
  Future<Either<Failure, void>> deleteReceipt(String id);

  // Tags
  Future<Either<Failure, List<ReceiptTag>>> getTags();
  Future<Either<Failure, ReceiptTag>> createTag({required String name, required String color});
  Future<Either<Failure, ReceiptTag>> updateTag({required String id, String? name, String? color});
  Future<Either<Failure, void>> deleteTag(String id);
}
