import 'package:flutter/foundation.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../../domain/usecases/create_invoice.dart';
import '../../domain/usecases/get_invoices.dart';
import '../../domain/usecases/get_invoice_by_id.dart';
import '../../domain/usecases/submit_invoice.dart';
import '../../domain/usecases/create_payment_request.dart';
import '../../domain/usecases/get_payment_requests.dart';
import '../../domain/usecases/cancel_payment_request.dart';
import '../../domain/usecases/cancel_transfer.dart';
import '../../domain/usecases/get_my_transfers.dart';
import '../../domain/usecases/initiate_payment.dart';
import '../../domain/usecases/verify_otp_and_pay.dart';
import '../../domain/usecases/get_my_balance.dart';

class InvoiceProvider with ChangeNotifier {
  final CreateInvoice createInvoiceUseCase;
  final GetInvoices getInvoicesUseCase;
  final GetInvoiceById getInvoiceByIdUseCase;
  final SubmitInvoice submitInvoiceUseCase;
  final CreatePaymentRequest createPaymentRequestUseCase;
  final GetPaymentRequests getPaymentRequestsUseCase;
  final CancelPaymentRequest cancelPaymentRequestUseCase;
  final CancelTransfer cancelTransferUseCase;
  final GetMyTransfers getMyTransfersUseCase;
  final InitiatePayment initiatePaymentUseCase;
  final VerifyOTPAndPay verifyOTPAndPayUseCase;
  final GetMyBalance getMyBalanceUseCase;

  InvoiceProvider({
    required this.createInvoiceUseCase,
    required this.getInvoicesUseCase,
    required this.getInvoiceByIdUseCase,
    required this.submitInvoiceUseCase,
    required this.createPaymentRequestUseCase,
    required this.getPaymentRequestsUseCase,
    required this.cancelPaymentRequestUseCase,
    required this.cancelTransferUseCase,
    required this.getMyTransfersUseCase,
    required this.initiatePaymentUseCase,
    required this.verifyOTPAndPayUseCase,
    required this.getMyBalanceUseCase,
  });

  // State
  bool _isLoading = false;
  String? _errorMessage;
  List<Invoice> _invoices = [];
  List<Transfer> _transfers = [];
  MyBalance? _myBalance;
  Invoice? _currentInvoice;
  Invoice? _selectedInvoice;
  
  // Payment Requests
  List<PaymentRequest> _paymentRequests = [];
  PaymentRequest? _activePaymentRequest;
  
  // Transfers
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
  
  // Payment Request getters
  List<PaymentRequest> get paymentRequests => _paymentRequests;
  PaymentRequest? get activePaymentRequest => _activePaymentRequest;
  List<Transfer> get myPendingTransfers => _myPendingTransfers;
  List<Transfer> get myCompletedTransfers => _myCompletedTransfers;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _errorMessage = message;
    notifyListeners();
  }

  // Create Invoice
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

    final result = await createInvoiceUseCase(
      groupId: groupId,
      title: title,
      amountTotal: amountTotal,
      items: items,
      imageUrl: imageUrl,
      note: note,
      currency: currency,
    );

    return result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
        return false;
      },
      (invoice) {
        _currentInvoice = invoice;
        _invoices.insert(0, invoice);
        _setLoading(false);
        return true;
      },
    );
  }

  // Get Invoices
  Future<void> loadInvoices(String groupId, {String? status}) async {
    _setLoading(true);
    _setError(null);

    final result = await getInvoicesUseCase(groupId, status: status);

    result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
      },
      (invoices) {
        _invoices = invoices;
        _setLoading(false);
      },
    );
  }

  // Fetch Invoice By ID
  Future<void> fetchInvoiceById(String groupId, String invoiceId) async {
    _setError(null);

    final result = await getInvoiceByIdUseCase(groupId, invoiceId);

    result.fold(
      (failure) {
        _setError(failure.toString());
        _selectedInvoice = null;
      },
      (invoice) {
        _selectedInvoice = invoice;
      },
    );
    notifyListeners();
  }

  // Submit Invoice
  Future<bool> submitInvoice(String groupId, String invoiceId) async {
    _setLoading(true);
    _setError(null);

    final result = await submitInvoiceUseCase(groupId, invoiceId);

    return result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
        return false;
      },
      (invoice) {
        _currentInvoice = invoice;
        // Update invoice in list
        final index = _invoices.indexWhere((i) => i.id == invoiceId);
        if (index != -1) {
          _invoices[index] = invoice;
        }
        _setLoading(false);
        return true;
      },
    );
  }

  // Create Payment Request
  Future<bool> createPaymentRequest(String groupId) async {
    _setLoading(true);
    _setError(null);

    final result = await createPaymentRequestUseCase(groupId);

    return result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
        return false;
      },
      (paymentRequest) {
        _setLoading(false);
        return true;
      },
    );
  }



  // Initiate Payment
  Future<Map<String, dynamic>?> initiatePayment(String transferId, {String? totpToken}) async {
    _setLoading(true);
    _setError(null);

    final result = await initiatePaymentUseCase(transferId, totpToken: totpToken);

    return result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
        return null;
      },
      (data) {
        _setLoading(false);
        return data;
      },
    );
  }

  // Verify OTP and Pay
  Future<bool> verifyOTPAndPay(String transferId, String otp) async {
    _setLoading(true);
    _setError(null);

    final result = await verifyOTPAndPayUseCase(transferId, otp);

    return result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
        return false;
      },
      (transfer) {
        // Update transfer in list
        final index = _transfers.indexWhere((t) => t.id == transferId);
        if (index != -1) {
          _transfers[index] = transfer;
        }
        _setLoading(false);
        return true;
      },
    );
  }

  // Get My Balance
  Future<void> loadMyBalance(String groupId) async {
    _setLoading(true);
    _setError(null);

    final result = await getMyBalanceUseCase(groupId);

    result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
      },
      (balance) {
        _myBalance = balance;
        _setLoading(false);
      },
    );
  }

  // Load Payment Requests
  Future<void> loadPaymentRequests(String groupId) async {
    _setLoading(true);
    _setError(null);

    final result = await getPaymentRequestsUseCase(groupId);

    result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
      },
      (requests) {
        _paymentRequests = requests;
        // Find active request (ISSUED or PARTIALLY_PAID)
        try {
          _activePaymentRequest = requests.firstWhere(
            (r) => r.status == 'ISSUED' || r.status == 'PARTIALLY_PAID',
          );
        } catch (e) {
          // No active request found
          _activePaymentRequest = null;
        }
        _setLoading(false);
      },
    );
  }

  // Load My Transfers
  Future<void> loadMyTransfers(String groupId) async {
    _setLoading(true);
    _setError(null);

    final result = await getMyTransfersUseCase(groupId);

    result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
      },
      (transfersData) {
        // getMyTransfers returns List of transfers
        if (transfersData is List) {
          _myPendingTransfers = transfersData.where((t) => t.status == 'PENDING').toList();
          _myCompletedTransfers = transfersData.where((t) => t.status == 'COMPLETED').toList();
        }
        _setLoading(false);
      },
    );
  }

  // Cancel Payment Request
  Future<bool> cancelPaymentRequest(String groupId, String requestId) async {
    _setLoading(true);
    _setError(null);

    final result = await cancelPaymentRequestUseCase(groupId, requestId);

    return result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
        return false;
      },
      (_) {
        // Reload payment requests
        loadPaymentRequests(groupId);
        _setLoading(false);
        return true;
      },
    );
  }

  // Cancel Single Transfer
  Future<bool> cancelTransfer(String transferId, String groupId) async {
    _setLoading(true);
    _setError(null);

    final result = await cancelTransferUseCase(transferId);

    return result.fold(
      (failure) {
        _setError(failure.toString());
        _setLoading(false);
        return false;
      },
      (_) {
        // Reload transfers and payment requests
        loadMyTransfers(groupId);
        loadPaymentRequests(groupId);
        _setLoading(false);
        return true;
      },
    );
  }

  void clearError() {
    _setError(null);
  }
}
