import 'package:dio/dio.dart';
import 'package:splitpal/models/savings_goal.dart';
// SavingsDeposit is exported from savings_goal.dart

/// API wrapper for all Savings endpoints.
class SavingsApi {
  final Dio _dio;

  SavingsApi(this._dio);

  // ─── Goals ─────────────────────────────────────────────
  Future<List<SavingsGoal>> getGoals() async {
    final resp = await _dio.get('/api/savings/goals');
    final data = resp.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      final list = data['data'] as List;
      return list
          .map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data
          .map((e) => SavingsGoal.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<SavingsGoal> createGoal({
    required String name,
    required double targetAmount,
    String? icon,
    DateTime? deadline,
  }) async {
    final resp = await _dio.post('/api/savings/goals', data: {
      'name': name,
      'targetAmount': targetAmount,
      if (icon != null) 'icon': icon,
      if (deadline != null) 'deadline': deadline.toIso8601String(),
    });
    final body = resp.data;
    final goalJson =
        (body is Map<String, dynamic> && body.containsKey('data'))
            ? body['data'] as Map<String, dynamic>
            : body as Map<String, dynamic>;
    return SavingsGoal.fromJson(goalJson);
  }

  Future<SavingsGoal> getGoalDetail(String goalId) async {
    final resp = await _dio.get('/api/savings/goals/$goalId');
    final body = resp.data;
    final goalJson =
        (body is Map<String, dynamic> && body.containsKey('data'))
            ? body['data'] as Map<String, dynamic>
            : body as Map<String, dynamic>;
    return SavingsGoal.fromJson(goalJson);
  }

  Future<void> deleteGoal(String goalId) async {
    await _dio.delete('/api/savings/goals/$goalId');
  }

  // ─── Deposits ──────────────────────────────────────────
  Future<SavingsDeposit> createDeposit({
    required String goalId,
    required double amount,
    required int termDays,
  }) async {
    final resp = await _dio.post('/api/savings/goals/$goalId/deposits', data: {
      'amount': amount,
      'term': termDays,
    });
    final body = resp.data;
    final depositJson =
        (body is Map<String, dynamic> && body.containsKey('data'))
            ? body['data'] as Map<String, dynamic>
            : body as Map<String, dynamic>;
    return SavingsDeposit.fromJson(depositJson);
  }

  Future<Map<String, dynamic>> withdrawDeposit(String depositId) async {
    final resp = await _dio.post('/api/savings/deposits/$depositId/withdraw');
    return resp.data as Map<String, dynamic>;
  }
}
