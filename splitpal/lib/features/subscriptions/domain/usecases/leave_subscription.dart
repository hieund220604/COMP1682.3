import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/subscription_repository.dart';

class LeaveSubscription {
  final SubscriptionRepository repository;

  LeaveSubscription(this.repository);

  Future<Either<Failure, void>> call(String id) async {
    return await repository.leaveSubscription(id);
  }
}
