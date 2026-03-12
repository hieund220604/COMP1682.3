import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class CreateSubscription {
  final SubscriptionRepository repository;

  CreateSubscription(this.repository);

  Future<Either<Failure, Subscription>> call({
    required String groupId,
    required String name,
    required double amount,
    required String billingCycle,
    String? description,
    DateTime? startDate,
  }) {
    return repository.createSubscription(
      groupId: groupId,
      name: name,
      amount: amount,
      billingCycle: billingCycle,
      description: description,
      startDate: startDate,
    );
  }
}
