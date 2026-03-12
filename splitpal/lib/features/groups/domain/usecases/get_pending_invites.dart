import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/group_repository.dart';

class GetPendingInvites {
  final GroupRepository repository;

  GetPendingInvites(this.repository);

  Future<Either<Failure, List<dynamic>>> call() async {
    return await repository.getPendingInvites();
  }
}
