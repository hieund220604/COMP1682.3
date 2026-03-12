import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../repositories/group_repository.dart';

class CreateGroup {
  final GroupRepository repository;

  CreateGroup(this.repository);

  Future<Either<Failure, Map<String, dynamic>>> call(String name, String currency) async {
    return await repository.createGroup(name, currency);
  }
}
