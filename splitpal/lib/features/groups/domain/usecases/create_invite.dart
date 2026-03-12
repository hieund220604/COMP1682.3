import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/group_repository.dart';

class CreateInvite {
  final GroupRepository repository;

  CreateInvite(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(String groupId, String email) async {
    return await repository.createInvite(groupId, email);
  }
}
