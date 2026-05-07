import 'package:flutter/foundation.dart';

import '../../core/network/dio_client.dart';
import '../../models/subscription.dart';

/// SubscriptionProvider — v2
/// Handles all subscription operations: create, invite, respond, leave, cancel.
class SubscriptionProvider extends ChangeNotifier {
  final DioClient _dio;

  SubscriptionProvider({required DioClient dio}) : _dio = dio;

  // ─── State ──────────────────────────────────────────────────────────────────
  List<Subscription> _subscriptions = [];
  Subscription? _selected;
  List<Map<String, dynamic>> _billingHistory = [];
  bool _isLoading = false;
  bool _isDetailLoading = false;
  bool _isProcessing = false;
  bool _isBillingHistoryLoading = false;
  String? _error;
  String? _actionError;

  List<Subscription> get subscriptions => _subscriptions;
  Subscription? get selected => _selected;
  List<Map<String, dynamic>> get billingHistory => _billingHistory;
  bool get isLoading => _isLoading;
  bool get isDetailLoading => _isDetailLoading;
  bool get isProcessing => _isProcessing;
  bool get isBillingHistoryLoading => _isBillingHistoryLoading;
  String? get error => _error;
  String? get actionError => _actionError;
  void clearActionError() {
    _actionError = null;
  }

  // ─── Fetch All ──────────────────────────────────────────────────────────────
  Future<void> fetchSubscriptions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _dio.get('/subscriptions');
      final data = resp.data['data'];
      if (data is List) {
        _subscriptions = data.map((j) => Subscription.fromJson(j)).toList();
      }
    } catch (e) {
      _error = e.toString();
      _subscriptions = [];
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Fetch Detail ────────────────────────────────────────────────────────────
  Future<void> fetchSubscription(String id) async {
    _isDetailLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _dio.get('/subscriptions/$id');
      _selected = Subscription.fromJson(resp.data['data']);
    } catch (e) {
      _error = e.toString();
      _selected = null;
    }

    _isDetailLoading = false;
    notifyListeners();
  }

  // ─── Billing History ─────────────────────────────────────────────────────────
  Future<void> fetchBillingHistory(String id) async {
    _isBillingHistoryLoading = true;
    notifyListeners();

    try {
      final resp = await _dio.get('/subscriptions/$id/billing-history');
      final data = resp.data['data'];
      _billingHistory = data is List
          ? data.cast<Map<String, dynamic>>()
          : <Map<String, dynamic>>[];
    } catch (_) {
      _billingHistory = [];
    }

    _isBillingHistoryLoading = false;
    notifyListeners();
  }

  // ─── Create ──────────────────────────────────────────────────────────────────
  /// Create a subscription. [amount] = fixed fee per member per cycle.
  Future<bool> create({
    String? groupId,
    required String name,
    required double amount,
    required String billingCycle,
    String? description,
  }) async {
    _isProcessing = true;
    _actionError = null;
    notifyListeners();

    try {
      final resp = await _dio.post('/subscriptions', data: {
        if (groupId != null) 'groupId': groupId,
        'name': name,
        'amount': amount,
        'billingCycle': billingCycle,
        if (description != null) 'description': description,
      });
      final sub = Subscription.fromJson(resp.data['data']);
      _subscriptions = [sub, ..._subscriptions];
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _actionError = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Invite Member ───────────────────────────────────────────────────────────
  Future<bool> invite({
    required String subscriptionId,
    required String inviteeId,
  }) async {
    _isProcessing = true;
    _actionError = null;
    notifyListeners();

    try {
      await _dio.post('/subscriptions/$subscriptionId/invite', data: {
        'inviteeId': inviteeId,
      });
      // Refresh detail to show new pending invitation
      await fetchSubscription(subscriptionId);
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _actionError = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Respond to Invitation ───────────────────────────────────────────────────
  /// [accept] = true to join (charges immediately), false to decline.
  Future<bool> respondToInvitation({
    required String subscriptionId,
    required String invitationId,
    required bool accept,
    String? categoryTagId,
  }) async {
    _isProcessing = true;
    _actionError = null;
    notifyListeners();

    try {
      await _dio.post(
        '/subscriptions/$subscriptionId/invite/respond',
        data: {
          'invitationId': invitationId,
          'accept': accept,
          if (categoryTagId != null) 'categoryTagId': categoryTagId,
        },
      );
      // Refresh both list and detail
      await Future.wait([
        fetchSubscriptions(),
        fetchSubscription(subscriptionId),
      ]);
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _actionError = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Cancel (owner) ──────────────────────────────────────────────────────────
  Future<bool> cancel(String id) async {
    _isProcessing = true;
    _actionError = null;
    notifyListeners();

    try {
      final resp = await _dio.post('/subscriptions/$id/cancel');
      final updated = Subscription.fromJson(resp.data['data']);
      _selected = updated;
      _subscriptions = _subscriptions
          .map((s) => s.id == updated.id ? updated : s)
          .toList(growable: false);
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _actionError = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Leave (member) ──────────────────────────────────────────────────────────
  Future<bool> leave(String id) async {
    _isProcessing = true;
    _actionError = null;
    notifyListeners();

    try {
      await _dio.post('/subscriptions/$id/leave');
      await fetchSubscriptions();
      _isProcessing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _actionError = e.toString();
      _isProcessing = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Process Charges (admin/cron trigger) ────────────────────────────────────
  Future<Map<String, dynamic>?> processCharges() async {
    _isProcessing = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _dio.post('/subscriptions/process-charges');
      _isProcessing = false;
      notifyListeners();
      return resp.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      _error = e.toString();
      _isProcessing = false;
      notifyListeners();
      return null;
    }
  }
}
