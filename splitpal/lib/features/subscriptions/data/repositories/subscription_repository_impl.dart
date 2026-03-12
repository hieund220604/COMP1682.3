import 'package:dartz/dartz.dart';
import 'package:splitpal/core/error/exceptions.dart';
import 'package:splitpal/core/error/failures.dart';

import '../../domain/entities/subscription.dart';
import '../../domain/repositories/subscription_repository.dart';
import '../datasources/subscription_remote_data_source.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final SubscriptionRemoteDataSource remoteDataSource;

  SubscriptionRepositoryImpl(this.remoteDataSource);

  @override
  Future<Either<Failure, List<Subscription>>> getSubscriptions() async {
    try {
      final result = await remoteDataSource.getSubscriptions();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Subscription>> getSubscriptionById(String id) async {
    try {
      final result = await remoteDataSource.getSubscriptionById(id);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Subscription>> createSubscription({
    required String groupId,
    required String name,
    required double amount,
    required String billingCycle,
    String? description,
    DateTime? startDate,
  }) async {
    try {
      final result = await remoteDataSource.createSubscription(
        groupId: groupId,
        name: name,
        amount: amount,
        billingCycle: billingCycle,
        description: description,
        startDate: startDate,
      );
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Subscription>> cancelSubscription(String id) async {
    try {
      final result = await remoteDataSource.cancelSubscription(id);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Subscription>> pauseSubscription(String id) async {
    try {
      final result = await remoteDataSource.pauseSubscription(id);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> leaveSubscription(String id) async {
    try {
      await remoteDataSource.leaveSubscription(id);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getBillingHistory(String id) async {
    try {
      final result = await remoteDataSource.getBillingHistory(id);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Subscription>> resumeSubscription(String id) async {
    try {
      final result = await remoteDataSource.resumeSubscription(id);
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> processCharges() async {
    try {
      final result = await remoteDataSource.processCharges();
      return Right(result);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
