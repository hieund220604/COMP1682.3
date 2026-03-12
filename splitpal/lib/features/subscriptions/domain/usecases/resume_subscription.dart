import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../entities/subscription.dart';
import '../repositories/subscription_repository.dart';

class ResumeSubscription {
  final SubscriptionRepository repository;

  ResumeSubscription(this.repository);

  Future<Either<Failure, Subscription>> call(String id) async {
    return await repository.resumeSubscription(id);
  }
}
