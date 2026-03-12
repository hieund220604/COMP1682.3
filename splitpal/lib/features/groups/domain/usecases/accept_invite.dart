import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/group_repository.dart';

class AcceptInvite {
  final GroupRepository repository;

  AcceptInvite(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(String token) async {
    return await repository.acceptInvite(token);
  }
}
