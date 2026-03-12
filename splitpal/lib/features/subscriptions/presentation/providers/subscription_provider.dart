import 'package:flutter/foundation.dart';

import '../../domain/entities/subscription.dart';
import '../../domain/usecases/get_subscriptions.dart';
import '../../domain/usecases/get_subscription_detail.dart';
import '../../domain/usecases/create_subscription.dart';
import '../../domain/usecases/cancel_subscription.dart';
import '../../domain/usecases/resume_subscription.dart';
import '../../domain/usecases/leave_subscription.dart';
import '../../domain/usecases/get_billing_history.dart';
import '../../domain/usecases/process_charges.dart';

class SubscriptionProvider extends ChangeNotifier {
  final GetSubscriptions _getSubscriptions;
  final GetSubscriptionDetail _getSubscriptionDetail;
  final CreateSubscription _createSubscription;
  final CancelSubscription _cancelSubscription;
  final ResumeSubscription _resumeSubscription;
  final LeaveSubscription _leaveSubscription;
  final GetBillingHistory _getBillingHistory;
  final ProcessCharges _processCharges;

  SubscriptionProvider({
    required GetSubscriptions getSubscriptions,
    required GetSubscriptionDetail getSubscriptionDetail,
    required CreateSubscription createSubscription,
    required CancelSubscription cancelSubscription,
    required ResumeSubscription resumeSubscription,
    required LeaveSubscription leaveSubscription,
    required GetBillingHistory getBillingHistory,
    required ProcessCharges processCharges,
  })  : _getSubscriptions = getSubscriptions,
        _getSubscriptionDetail = getSubscriptionDetail,
        _createSubscription = createSubscription,
        _cancelSubscription = cancelSubscription,
        _resumeSubscription = resumeSubscription,
        _leaveSubscription = leaveSubscription,
        _getBillingHistory = getBillingHistory,
        _processCharges = processCharges;

  List<Subscription> _subscriptions = [];
  Subscription? _selected;
  List<Map<String, dynamic>> _billingHistory = [];
  bool _isLoading = false;
  bool _isDetailLoading = false;
  bool _isProcessing = false;
  bool _isBillingHistoryLoading = false;
  String? _error;

  List<Subscription> get subscriptions => _subscriptions;
  Subscription? get selected => _selected;
  List<Map<String, dynamic>> get billingHistory => _billingHistory;
  bool get isLoading => _isLoading;
  bool get isDetailLoading => _isDetailLoading;
  bool get isProcessing => _isProcessing;
  bool get isBillingHistoryLoading => _isBillingHistoryLoading;
  String? get error => _error;

  // Separate error for action-level failures (cancel, resume) so they
  // don't replace the whole list with an error screen.
  String? _actionError;
  String? get actionError => _actionError;
  void clearActionError() { _actionError = null; }

  Future<void> fetchSubscriptions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final result = await _getSubscriptions();
    result.fold(
      (failure) {
        _error = failure.message;
        _subscriptions = [];
      },
      (data) => _subscriptions = data,
    );

    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchSubscription(String id) async {
    _isDetailLoading = true;
    _error = null;
    notifyListeners();

    final result = await _getSubscriptionDetail(id);
    result.fold(
      (failure) {
        _error = failure.message;
        _selected = null;
      },
      (data) => _selected = data,
    );

    _isDetailLoading = false;
    notifyListeners();
  }

  Future<void> fetchBillingHistory(String id) async {
    _isBillingHistoryLoading = true;
    notifyListeners();

    final result = await _getBillingHistory(id);
    result.fold(
      (failure) => _billingHistory = [],
      (data) => _billingHistory = data,
    );

    _isBillingHistoryLoading = false;
    notifyListeners();
  }

  Future<bool> create({
    required String groupId,
    required String name,
    required double amount,
    required String billingCycle,
    String? description,
    DateTime? startDate,
  }) async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    final result = await _createSubscription(
      groupId: groupId,
      name: name,
      amount: amount,
      billingCycle: billingCycle,
      description: description,
      startDate: startDate,
    );

    bool success = false;
    result.fold(
      (failure) {
        _error = failure.message;
      },
      (data) {
        success = true;
        _subscriptions = [data, ..._subscriptions];
      },
    );

    _isProcessing = false;
    notifyListeners();
    return success;
  }

  Future<bool> cancel(String id) async {
    _isProcessing = true;
    _actionError = null;
    notifyListeners();

    final result = await _cancelSubscription(id);
    bool success = false;

    result.fold(
      (failure) => _actionError = failure.message,  // ← NOT _error, so list stays
      (data) {
        success = true;
        _selected = data;
        _subscriptions = _subscriptions
            .map((s) => s.id == data.id ? data : s)
            .toList(growable: false);
      },
    );

    _isProcessing = false;
    notifyListeners();
    return success;
  }

  Future<bool> leave(String id) async {
    _isProcessing = true;
    _actionError = null;
    notifyListeners();

    final result = await _leaveSubscription(id);
    bool success = false;

    result.fold(
      (failure) => _actionError = failure.message,
      (_) => success = true,
    );

    _isProcessing = false;
    notifyListeners();
    return success;
  }

  Future<Map<String, dynamic>?> processCharges() async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    final result = await _processCharges();
    Map<String, dynamic>? payload;
    result.fold(
      (failure) => _error = failure.message,
      (data) => payload = data,
    );

    _isProcessing = false;
    notifyListeners();
    return payload;
  }

  Future<bool> resume(String id) async {
    _isProcessing = true;
    _actionError = null;
    notifyListeners();

    final result = await _resumeSubscription(id);
    bool success = false;

    result.fold(
      (failure) => _actionError = failure.message,  // ← NOT _error
      (data) {
        success = true;
        _selected = data;
        _subscriptions = _subscriptions
            .map((s) => s.id == data.id ? data : s)
            .toList(growable: false);
      },
    );

    _isProcessing = false;
    notifyListeners();
    return success;
  }
}
