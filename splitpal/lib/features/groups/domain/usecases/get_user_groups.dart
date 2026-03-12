import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/group_repository.dart';

class GetUserGroups {
  final GroupRepository repository;

  GetUserGroups(this.repository);

  Future<Either<Failure, List<dynamic>>> call() async {
    return await repository.getUserGroups();
  }
}
