import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';

abstract class SubscriptionRepository {
  Future<Either<Failure, List<Subscription>>> getSubscriptions();
  Future<Either<Failure, Subscription>> getSubscriptionById(String id);
  Future<Either<Failure, Subscription>> createSubscription({
    required String groupId,
    required String name,
    required double amount,
    required String billingCycle,
    String? description,
    DateTime? startDate,
  });
  Future<Either<Failure, Subscription>> cancelSubscription(String id);
  Future<Either<Failure, Subscription>> pauseSubscription(String id);
  Future<Either<Failure, Subscription>> resumeSubscription(String id);
  Future<Either<Failure, void>> leaveSubscription(String id);
  Future<Either<Failure, List<Map<String, dynamic>>>> getBillingHistory(String id);
  Future<Either<Failure, Map<String, dynamic>>> processCharges();
}
