import 'package:flutter/foundation.dart';
import 'package:splitpal/core/network/dio_client.dart';
import 'package:splitpal/core/constants/api_constants.dart';

/// Provider for Savings Goals feature.
/// Follows the same fat-provider pattern as GroupProvider, ReceiptProvider, etc.
class SavingsProvider with ChangeNotifier {
  final DioClient _dio;

  SavingsProvider({required DioClient dio}) : _dio = dio;

  // ─── State ──────────────────────────────────────────────
  List<Map<String, dynamic>> _goals = [];
  Map<String, dynamic>? _currentGoal;
  Map<String, dynamic> _summary = {};
  bool _isLoading = false;
  String? _error;

  List<Map<String, dynamic>> get goals => _goals;
  Map<String, dynamic>? get currentGoal => _currentGoal;
  Map<String, dynamic> get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ─── Fetch All Goals ────────────────────────────────────
  Future<void> fetchGoals() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _dio.get(ApiConstants.savingsGoals);
      final data = resp.data;
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        final payload = data['data'] as Map<String, dynamic>;
        _goals = List<Map<String, dynamic>>.from(payload['goals'] ?? []);
        _summary = Map<String, dynamic>.from(payload['summary'] ?? {});
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Fetch Single Goal ──────────────────────────────────
  Future<void> fetchGoalDetail(String goalId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final resp = await _dio.get(ApiConstants.savingsGoalById(goalId));
      final data = resp.data;
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        _currentGoal = data['data'] as Map<String, dynamic>;
      } else if (data is Map<String, dynamic>) {
        _currentGoal = data;
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ─── Create Goal ────────────────────────────────────────
  Future<bool> createGoal({
    required String name,
    required double targetAmount,
    String? icon,
    String? deadline,
  }) async {
    try {
      await _dio.post(ApiConstants.savingsGoals, data: {
        'name': name,
        'targetAmount': targetAmount,
        if (icon != null) 'icon': icon,
        if (deadline != null) 'deadline': deadline,
      });
      await fetchGoals();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Create Deposit ─────────────────────────────────────
  Future<bool> createDeposit({
    required String goalId,
    required double amount,
    required int term,
  }) async {
    try {
      await _dio.post(ApiConstants.savingsGoalDeposits(goalId), data: {
        'amount': amount,
        'term': term,
      });
      await fetchGoalDetail(goalId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  // ─── Withdraw Deposit ───────────────────────────────────
  Future<Map<String, dynamic>?> withdrawDeposit({
    required String depositId,
    required String goalId,
  }) async {
    try {
      final resp = await _dio.post(ApiConstants.savingsDepositWithdraw(depositId));
      await fetchGoalDetail(goalId);
      final data = resp.data;
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return data['data'] as Map<String, dynamic>;
      }
      return data as Map<String, dynamic>?;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  // ─── Interest Preview ───────────────────────────────────
  Future<Map<String, dynamic>?> getInterestPreview({
    required double amount,
    required int term,
  }) async {
    try {
      final resp = await _dio.get(
        ApiConstants.savingsInterestPreview,
        queryParameters: {'amount': amount, 'term': term},
      );
      final data = resp.data;
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        return data['data'] as Map<String, dynamic>;
      }
      return data as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  // ─── Delete Goal ────────────────────────────────────────
  Future<bool> deleteGoal(String goalId) async {
    try {
      await _dio.delete(ApiConstants.savingsGoalById(goalId));
      await fetchGoals();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
