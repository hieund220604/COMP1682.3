import 'package:splitpal/core/constants/api_constants.dart';
import 'package:splitpal/core/error/exceptions.dart';
import 'package:splitpal/core/network/dio_client.dart';

import '../models/subscription_model.dart';

abstract class SubscriptionRemoteDataSource {
  Future<List<SubscriptionModel>> getSubscriptions();
  Future<SubscriptionModel> getSubscriptionById(String id);
  Future<SubscriptionModel> createSubscription({
    required String groupId,
    required String name,
    required double amount,
    required String billingCycle,
    String? description,
    DateTime? startDate,
  });
  Future<SubscriptionModel> cancelSubscription(String id);
  Future<SubscriptionModel> pauseSubscription(String id);
  Future<SubscriptionModel> resumeSubscription(String id);
  Future<void> leaveSubscription(String id);
  Future<List<Map<String, dynamic>>> getBillingHistory(String id);
  Future<Map<String, dynamic>> processCharges();
}

class SubscriptionRemoteDataSourceImpl implements SubscriptionRemoteDataSource {
  final DioClient dioClient;

  SubscriptionRemoteDataSourceImpl(this.dioClient);

  Map<String, dynamic> _unwrapData(dynamic data) {
    if (data is Map<String, dynamic>) {
      if (data['data'] is Map<String, dynamic>) return data['data'] as Map<String, dynamic>;
      return data;
    }
    return {};
  }

  List<dynamic> _unwrapList(dynamic data) {
    if (data is Map<String, dynamic> && data['data'] is List) {
      return data['data'] as List;
    }
    if (data is List) return data;
    return [];
  }

  @override
  Future<List<SubscriptionModel>> getSubscriptions() async {
    try {
      final response = await dioClient.get(ApiConstants.subscriptions);
      if (response.statusCode == 200) {
        final list = _unwrapList(response.data);
        return list
            .whereType<Map<String, dynamic>>()
            .map(SubscriptionModel.fromJson)
            .toList();
      }
      throw ServerException(message: 'Failed to fetch subscriptions');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<SubscriptionModel> getSubscriptionById(String id) async {
    try {
      final response = await dioClient.get(ApiConstants.subscriptionById(id));
      if (response.statusCode == 200) {
        final json = _unwrapData(response.data);
        return SubscriptionModel.fromJson(json);
      }
      throw ServerException(message: 'Failed to fetch subscription');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<SubscriptionModel> createSubscription({
    required String groupId,
    required String name,
    required double amount,
    required String billingCycle,
    String? description,
    DateTime? startDate,
  }) async {
    try {
      final response = await dioClient.post(
        ApiConstants.subscriptions,
        data: {
          'groupId': groupId,
          'name': name,
          'description': description,
          'amount': amount,
          'billingCycle': billingCycle,
          if (startDate != null) 'startDate': startDate.toIso8601String(),
        },
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = _unwrapData(response.data);
        return SubscriptionModel.fromJson(json);
      }
      throw ServerException(
        message: response.data?['error']?['message'] ?? 'Failed to create subscription',
      );
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<SubscriptionModel> cancelSubscription(String id) async {
    try {
      final response = await dioClient.post(ApiConstants.cancelSubscription(id));
      if (response.statusCode == 200) {
        final json = _unwrapData(response.data);
        return SubscriptionModel.fromJson(json);
      }
      throw ServerException(message: 'Failed to cancel subscription');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<SubscriptionModel> pauseSubscription(String id) async {
    try {
      final response = await dioClient.post(ApiConstants.pauseSubscription(id));
      if (response.statusCode == 200) {
        final json = _unwrapData(response.data);
        return SubscriptionModel.fromJson(json);
      }
      throw ServerException(message: 'Failed to pause subscription');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<void> leaveSubscription(String id) async {
    try {
      final response = await dioClient.post(ApiConstants.leaveSubscription(id));
      if (response.statusCode == 200) return;
      throw ServerException(message: 'Failed to leave subscription');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getBillingHistory(String id) async {
    try {
      final response = await dioClient.get(ApiConstants.billingHistory(id));
      if (response.statusCode == 200) {
        final list = _unwrapList(response.data);
        return list.whereType<Map<String, dynamic>>().toList();
      }
      throw ServerException(message: 'Failed to fetch billing history');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<SubscriptionModel> resumeSubscription(String id) async {
    try {
      final response = await dioClient.post(ApiConstants.resumeSubscription(id));
      if (response.statusCode == 200) {
        final json = _unwrapData(response.data);
        return SubscriptionModel.fromJson(json);
      }
      throw ServerException(message: 'Failed to resume subscription');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }

  @override
  Future<Map<String, dynamic>> processCharges() async {
    try {
      final response = await dioClient.post(ApiConstants.processCharges);
      if (response.statusCode == 200) {
        return _unwrapData(response.data);
      }
      throw ServerException(message: 'Failed to process charges');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw ServerException(message: e.toString());
    }
  }
}
