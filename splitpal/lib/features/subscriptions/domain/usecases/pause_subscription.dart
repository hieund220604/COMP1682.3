import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class PauseSubscription {
  final SubscriptionRepository repository;

  PauseSubscription(this.repository);

  Future<Either<Failure, Subscription>> call(String id) async {
    return await repository.pauseSubscription(id);
  }
}
