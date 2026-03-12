import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/subscription_repository.dart';

class ProcessCharges {
  final SubscriptionRepository repository;

  ProcessCharges(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call() {
    return repository.processCharges();
  }
}
