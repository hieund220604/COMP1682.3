import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../core/network/dio_client.dart';
import '../../models/invoice.dart';

/// Fat Provider — calls DioClient directly for all invoice/payment/transfer ops.
class InvoiceProvider with ChangeNotifier {
  final DioClient _dio;

  InvoiceProvider({required DioClient dio}) : _dio = dio;

  // ─── State ──────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;
  List<Invoice> _invoices = [];
  final List<Transfer> _transfers = [];
  MyBalance? _myBalance;
  Invoice? _currentInvoice;
  Invoice? _selectedInvoice;

  List<PaymentRequest> _paymentRequests = [];
  PaymentRequest? _activePaymentRequest;
  List<Transfer> _myPendingTransfers = [];
  List<Transfer> _myCompletedTransfers = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get error => _errorMessage;
  List<Invoice> get invoices => _invoices;
  List<Transfer> get transfers => _transfers;
  MyBalance? get myBalance => _myBalance;
  Invoice? get currentInvoice => _currentInvoice;
  Invoice? get selectedInvoice => _selectedInvoice;
  List<PaymentRequest> get paymentRequests => _paymentRequests;
  PaymentRequest? get activePaymentRequest => _activePaymentRequest;
  List<Transfer> get myPendingTransfers => _myPendingTransfers;
  List<Transfer> get myCompletedTransfers => _myCompletedTransfers;

  void _setLoading(bool v) { _isLoading = v; notifyListeners(); }
  void _setError(String? m) { _errorMessage = m; notifyListeners(); }
  void clearError() => _setError(null);

  // ─── Create Invoice ─────────────────────────────────────
  Future<bool> createInvoice({
    required String groupId,
    required String title,
    required double amountTotal,
    required List<InvoiceItemCreate> items,
    String? imageUrl,
    String? note,
    String? currency,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.post('/invoices/$groupId', data: {
        'title': title,
        'amountTotal': amountTotal,
        'items': items.map((e) => e.toJson()).toList(),
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (note != null) 'note': note,
        if (currency != null) 'currency': currency,
      });
      final invoice = Invoice.fromJson(resp.data['data']);
      _currentInvoice = invoice;
      _invoices.insert(0, invoice);
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── Upload Image ───────────────────────────────────────
  Future<String?> uploadInvoiceImage(String imagePath) async {
    _setLoading(true);
    _setError(null);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(imagePath),
      });
      final resp = await _dio.post('/upload', data: formData);
      _setLoading(false);
      return resp.data['data']['url'] as String?;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  // ─── Load Invoices ──────────────────────────────────────
  Future<void> loadInvoices(String groupId, {String? status}) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.get(
        '/invoices/$groupId',
        queryParameters: status != null ? {'status': status} : null,
      );
      _invoices = (resp.data['data'] as List)
          .map((j) => Invoice.fromJson(j))
          .toList();
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  // ─── Fetch Invoice By ID ────────────────────────────────
  Future<void> fetchInvoiceById(String groupId, String invoiceId) async {
    _setError(null);
    try {
      final resp = await _dio.get('/invoices/$groupId/$invoiceId');
      _selectedInvoice = Invoice.fromJson(resp.data['data']);
    } catch (e) {
      _setError(e.toString());
      _selectedInvoice = null;
    }
    notifyListeners();
  }

  // ─── Submit Invoice ─────────────────────────────────────
  Future<bool> submitInvoice(String groupId, String invoiceId) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.post('/invoices/$groupId/$invoiceId/submit');
      final invoice = Invoice.fromJson(resp.data['data']);
      _currentInvoice = invoice;
      final idx = _invoices.indexWhere((i) => i.id == invoiceId);
      if (idx != -1) _invoices[idx] = invoice;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── Update Invoice ─────────────────────────────────────
  Future<bool> updateInvoice(
    String groupId,
    String invoiceId, {
    required String title,
    required double amountTotal,
    required List<Map<String, dynamic>> items,
    String? note,
    String? currency,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.put('/invoices/$groupId/$invoiceId', data: {
        'title': title,
        'amountTotal': amountTotal,
        'items': items,
        if (note != null) 'note': note,
        if (currency != null) 'currency': currency,
      });
      final invoice = Invoice.fromJson(resp.data['data']);
      _currentInvoice = invoice;
      _selectedInvoice = invoice;
      final idx = _invoices.indexWhere((i) => i.id == invoiceId);
      if (idx != -1) _invoices[idx] = invoice;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── Delete Invoice ─────────────────────────────────────
  Future<bool> deleteInvoice(String groupId, String invoiceId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _dio.delete('/invoices/$groupId/$invoiceId');
      _invoices.removeWhere((i) => i.id == invoiceId);
      if (_currentInvoice?.id == invoiceId) _currentInvoice = null;
      if (_selectedInvoice?.id == invoiceId) _selectedInvoice = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── Payment Requests ──────────────────────────────────
  Future<bool> createPaymentRequest(String groupId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _dio.post('/payment-requests/$groupId');
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<void> loadPaymentRequests(String groupId) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.get('/payment-requests/$groupId');
      _paymentRequests = (resp.data['data'] as List)
          .map((j) => PaymentRequest.fromJson(j))
          .toList();
      try {
        _activePaymentRequest = _paymentRequests.firstWhere(
          (r) => r.status == 'ISSUED' || r.status == 'PARTIALLY_PAID',
        );
      } catch (_) {
        _activePaymentRequest = null;
      }
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<bool> cancelPaymentRequest(String groupId, String requestId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _dio.post('/payment-requests/$groupId/$requestId/cancel');
      await loadPaymentRequests(groupId);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── Transfers ──────────────────────────────────────────
  Future<void> loadMyTransfers(String groupId) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.get('/transfers/group/$groupId');
      final data = resp.data['data'];

      if (data is Map) {
        final pending = (data['pending'] as List?)
                ?.map((j) => Transfer.fromJson(j))
                .toList() ??
            [];
        final completed = (data['completed'] as List?)
                ?.map((j) => Transfer.fromJson(j))
                .toList() ??
            [];
        final pendingIncoming = (data['pendingIncoming'] as List?)
                ?.map((j) => Transfer.fromJson(j))
                .toList() ??
            [];
        _myPendingTransfers = [...pending, ...pendingIncoming];
        _myCompletedTransfers = completed;
      } else if (data is List) {
        final all = data.map((j) => Transfer.fromJson(j)).toList();
        _myPendingTransfers = all.where((t) => t.status == 'PENDING').toList();
        _myCompletedTransfers =
            all.where((t) => t.status == 'COMPLETED').toList();
      }
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> initiatePayment(String transferId,
      {String? totpToken}) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.post(
        '/transfers/$transferId/pay',
        data: totpToken != null ? {'totpToken': totpToken} : null,
      );
      _setLoading(false);
      return resp.data['data'];
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return null;
    }
  }

  Future<bool> verifyOTPAndPay(String transferId, String otp, {String? categoryTagId}) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.post(
        '/transfers/$transferId/verify-otp',
        data: {
          'otp': otp,
          if (categoryTagId != null) 'categoryTagId': categoryTagId,
        },
      );
      final transfer = Transfer.fromJson(resp.data['data']);
      final idx = _transfers.indexWhere((t) => t.id == transferId);
      if (idx != -1) _transfers[idx] = transfer;
      _setLoading(false);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  Future<bool> cancelTransfer(String transferId, String groupId) async {
    _setLoading(true);
    _setError(null);
    try {
      await _dio.post('/transfers/$transferId/cancel');
      await loadMyTransfers(groupId);
      await loadPaymentRequests(groupId);
      return true;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return false;
    }
  }

  // ─── Balance ────────────────────────────────────────────
  Future<void> loadMyBalance(String groupId) async {
    _setLoading(true);
    _setError(null);
    try {
      final resp = await _dio.get('/invoices/$groupId/my-balance');
      _myBalance = MyBalance.fromJson(resp.data['data']);
      _setLoading(false);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }
}
