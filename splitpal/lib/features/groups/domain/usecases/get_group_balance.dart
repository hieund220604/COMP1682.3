import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/group_repository.dart';

class GetGroupBalance {
  final GroupRepository repository;

  GetGroupBalance(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(String groupId) async {
    return await repository.getGroupBalance(groupId);
  }
}
