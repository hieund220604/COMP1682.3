import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class GetSubscriptions {
  final SubscriptionRepository repository;

  GetSubscriptions(this.repository);

  Future<Either<Failure, List<Subscription>>> call() {
    return repository.getSubscriptions();
  }
}
