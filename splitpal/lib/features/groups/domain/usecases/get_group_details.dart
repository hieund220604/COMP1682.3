import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/group_repository.dart';

class GetGroupDetails {
  final GroupRepository repository;

  GetGroupDetails(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(String groupId) async {
    return await repository.getGroupDetails(groupId);
  }
}
