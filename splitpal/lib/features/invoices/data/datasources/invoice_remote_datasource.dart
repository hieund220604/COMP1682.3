import 'package:dio/dio.dart';
import '../../../../core/network/dio_client.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../models/invoice_model.dart';

abstract class InvoiceRemoteDataSource {
  Future<InvoiceModel> createInvoice({
    required String groupId,
    required String title,
    required double amountTotal,
    required List<InvoiceItemCreate> items,
    String? imageUrl,
    String? note,
    String? currency,
  });

  Future<List<InvoiceModel>> getInvoices(String groupId, {String? status});
  Future<InvoiceModel> getInvoiceById(String groupId, String invoiceId);
  
  Future<InvoiceModel> updateInvoice({
    required String groupId,
    required String invoiceId,
    String? title,
    List<InvoiceItemCreate>? items,
    String? imageUrl,
    String? note,
  });
  
  Future<void> deleteInvoice(String groupId, String invoiceId);
  Future<InvoiceModel> submitInvoice(String groupId, String invoiceId);

  Future<PaymentRequestModel> createPaymentRequest(String groupId);
  Future<List<PaymentRequestModel>> getPaymentRequests(String groupId);
  Future<PaymentRequestModel> getPaymentRequestById(String groupId, String requestId);
  Future<void> cancelPaymentRequest(String groupId, String requestId);

  Future<List<TransferModel>> getMyTransfers(String groupId);
  Future<TransferModel> getTransferById(String transferId);
  Future<Map<String, dynamic>> initiatePayment(String transferId, {String? totpToken});
  Future<TransferModel> verifyOTPAndPay(String transferId, String otp);
  Future<void> resendOTP(String transferId);

  Future<void> cancelTransfer(String transferId);

  Future<MyBalanceModel> getMyBalance(String groupId);
}

class InvoiceRemoteDataSourceImpl implements InvoiceRemoteDataSource {
  final DioClient dioClient;

  InvoiceRemoteDataSourceImpl({required this.dioClient});

  @override
  Future<InvoiceModel> createInvoice({
    required String groupId,
    required String title,
    required double amountTotal,
    required List<InvoiceItemCreate> items,
    String? imageUrl,
    String? note,
    String? currency,
  }) async {
    try {
      final response = await dioClient.post(
        '/invoices/$groupId',
        data: {
          'title': title,
          'amountTotal': amountTotal,
          'items': items.map((e) => e.toJson()).toList(),
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (note != null) 'note': note,
          if (currency != null) 'currency': currency,
        },
      );
      return InvoiceModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<InvoiceModel>> getInvoices(String groupId, {String? status}) async {
    try {
      final response = await dioClient.get(
        '/invoices/$groupId',
        queryParameters: status != null ? {'status': status} : null,
      );
      return (response.data['data'] as List)
          .map((json) => InvoiceModel.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<InvoiceModel> getInvoiceById(String groupId, String invoiceId) async {
    try {
      final response = await dioClient.get('/invoices/$groupId/$invoiceId');
      return InvoiceModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<InvoiceModel> updateInvoice({
    required String groupId,
    required String invoiceId,
    String? title,
    List<InvoiceItemCreate>? items,
    String? imageUrl,
    String? note,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (title != null) data['title'] = title;
      if (items != null) data['items'] = items.map((e) => e.toJson()).toList();
      if (imageUrl != null) data['imageUrl'] = imageUrl;
      if (note != null) data['note'] = note;

      final response = await dioClient.put(
        '/invoices/$groupId/$invoiceId',
        data: data,
      );
      return InvoiceModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> deleteInvoice(String groupId, String invoiceId) async {
    try {
      await dioClient.delete('/invoices/$groupId/$invoiceId');
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<InvoiceModel> submitInvoice(String groupId, String invoiceId) async {
    try {
      final response = await dioClient.post('/invoices/$groupId/$invoiceId/submit');
      return InvoiceModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<PaymentRequestModel> createPaymentRequest(String groupId) async {
    try {
      final response = await dioClient.post('/payment-requests/$groupId');
      return PaymentRequestModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<PaymentRequestModel>> getPaymentRequests(String groupId) async {
    try {
      final response = await dioClient.get('/payment-requests/$groupId');
      return (response.data['data'] as List)
          .map((json) => PaymentRequestModel.fromJson(json))
          .toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<PaymentRequestModel> getPaymentRequestById(String groupId, String requestId) async {
    try {
      final response = await dioClient.get('/payment-requests/$groupId/$requestId');
      return PaymentRequestModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> cancelPaymentRequest(String groupId, String requestId) async {
    try {
      await dioClient.post('/payment-requests/$groupId/$requestId/cancel');
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<List<TransferModel>> getMyTransfers(String groupId) async {
    try {
      final response = await dioClient.get('/transfers/group/$groupId');
      
      // Backend returns {pending: [...], completed: [...], pendingIncoming: [...]}
      final data = response.data['data'];
      
      if (data is Map) {
        final pending = (data['pending'] as List?)?.map((json) => TransferModel.fromJson(json)).toList() ?? [];
        final completed = (data['completed'] as List?)?.map((json) => TransferModel.fromJson(json)).toList() ?? [];
        final pendingIncoming = (data['pendingIncoming'] as List?)?.map((json) => TransferModel.fromJson(json)).toList() ?? [];
        return [...pending, ...completed, ...pendingIncoming];
      }
      
      // Fallback if data is a list
      return (data as List).map((json) => TransferModel.fromJson(json)).toList();
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<TransferModel> getTransferById(String transferId) async {
    try {
      final response = await dioClient.get('/transfers/$transferId');
      return TransferModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<Map<String, dynamic>> initiatePayment(String transferId, {String? totpToken}) async {
    try {
      final response = await dioClient.post(
        '/transfers/$transferId/pay',
        data: totpToken != null ? {'totpToken': totpToken} : null,
      );
      return response.data['data'];
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<TransferModel> verifyOTPAndPay(String transferId, String otp) async {
    try {
      final response = await dioClient.post(
        '/transfers/$transferId/verify-otp',
        data: {'otp': otp},
      );
      return TransferModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> resendOTP(String transferId) async {
    try {
      await dioClient.post('/transfers/$transferId/resend-otp');
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<void> cancelTransfer(String transferId) async {
    try {
      await dioClient.post('/transfers/$transferId/cancel');
    } catch (e) {
      throw _handleError(e);
    }
  }

  @override
  Future<MyBalanceModel> getMyBalance(String groupId) async {
    try {
      final response = await dioClient.get('/invoices/$groupId/my-balance');
      return MyBalanceModel.fromJson(response.data['data']);
    } catch (e) {
      throw _handleError(e);
    }
  }

  Exception _handleError(dynamic error) {
    if (error is DioException) {
      return Exception(error.response?.data['message'] ?? 'Network error occurred');
    }
    return Exception('An unexpected error occurred');
  }
}
