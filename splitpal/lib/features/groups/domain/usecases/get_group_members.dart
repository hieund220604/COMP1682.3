import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/group_repository.dart';

class GetGroupMembers {
  final GroupRepository repository;

  GetGroupMembers(this.repository);

  Future<Either<Failure, List<dynamic>>> call(String groupId) async {
    return await repository.getGroupMembers(groupId);
  }
}
