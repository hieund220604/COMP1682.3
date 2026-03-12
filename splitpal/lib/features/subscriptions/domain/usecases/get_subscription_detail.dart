import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class GetSubscriptionDetail {
  final SubscriptionRepository repository;

  GetSubscriptionDetail(this.repository);

  Future<Either<Failure, Subscription>> call(String id) {
    return repository.getSubscriptionById(id);
  }
}
