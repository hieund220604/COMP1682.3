import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/subscription_repository.dart';

class GetBillingHistory {
  final SubscriptionRepository repository;

  GetBillingHistory(this.repository);

  Future<Either<Failure, List<Map<String, dynamic>>>> call(String id) async {
    return await repository.getBillingHistory(id);
  }
}
