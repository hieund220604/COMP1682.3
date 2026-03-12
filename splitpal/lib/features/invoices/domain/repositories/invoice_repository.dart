import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/invoice.dart';

abstract class InvoiceRepository {
  // Invoices
  Future<Either<Failure, Invoice>> createInvoice({
    required String groupId,
    required String title,
    required double amountTotal,
    required List<InvoiceItemCreate> items,
    String? imageUrl,
    String? note,
    String? currency,
  });

  Future<Either<Failure, List<Invoice>>> getInvoices(String groupId, {String? status});
  
  Future<Either<Failure, Invoice>> getInvoiceById(String groupId, String invoiceId);
  
  Future<Either<Failure, Invoice>> updateInvoice({
    required String groupId,
    required String invoiceId,
    String? title,
    List<InvoiceItemCreate>? items,
    String? imageUrl,
    String? note,
  });
  
  Future<Either<Failure, void>> deleteInvoice(String groupId, String invoiceId);
  
  Future<Either<Failure, Invoice>> submitInvoice(String groupId, String invoiceId);

  // Payment Requests
  Future<Either<Failure, PaymentRequest>> createPaymentRequest(String groupId);
  
  Future<Either<Failure, List<PaymentRequest>>> getPaymentRequests(String groupId);
  
  Future<Either<Failure, PaymentRequest>> getPaymentRequestById(String groupId, String requestId);
  
  Future<Either<Failure, void>> cancelPaymentRequest(String groupId, String requestId);

  // Transfers
  Future<Either<Failure, List<Transfer>>> getMyTransfers(String groupId);
  
  Future<Either<Failure, Transfer>> getTransferById(String transferId);
  
  Future<Either<Failure, Map<String, dynamic>>> initiatePayment(String transferId, {String? totpToken});
  
  Future<Either<Failure, Transfer>> verifyOTPAndPay(String transferId, String otp);
  
  Future<Either<Failure, void>> resendOTP(String transferId);

  // Cancel single transfer
  Future<Either<Failure, void>> cancelTransfer(String transferId);

  // Balance
  Future<Either<Failure, MyBalance>> getMyBalance(String groupId);
}

class InvoiceItemCreate {
  final String name;
  final double amount;
  /// EQUAL | PERCENTAGE | CUSTOM | WEIGHT  (defaults to EQUAL)
  final String splitType;
  final List<String> assignedTo;
  final List<InvoiceItemSplitCreate> splits;

  InvoiceItemCreate({
    required this.name,
    required this.amount,
    this.splitType = 'EQUAL',
    required this.assignedTo,
    this.splits = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'amount': amount,
      'splitType': splitType,
      'assignedTo': assignedTo,
      if (splits.isNotEmpty) 'splits': splits.map((s) => s.toJson()).toList(),
    };
  }
}

class InvoiceItemSplitCreate {
  final String userId;
  final double value;

  InvoiceItemSplitCreate({required this.userId, required this.value});

  Map<String, dynamic> toJson() => {'userId': userId, 'value': value};
}
