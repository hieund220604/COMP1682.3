import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class CancelSubscription {
  final SubscriptionRepository repository;

  CancelSubscription(this.repository);

  Future<Either<Failure, Subscription>> call(String id) {
    return repository.cancelSubscription(id);
  }
}
