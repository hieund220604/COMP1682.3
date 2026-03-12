import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';

abstract class GroupRepository {
  Future<Either<Failure, List<dynamic>>> getUserGroups();
  Future<Either<Failure, List<dynamic>>> getPendingInvites();
  Future<Either<Failure, Map<String, dynamic>>> createGroup(String name, String currency);
  Future<Either<Failure, Map<String, dynamic>>> getGroupDetails(String groupId);
  Future<Either<Failure, List<dynamic>>> getGroupMembers(String groupId);
  Future<Either<Failure, Map<String, dynamic>>> createInvite(String groupId, String email);
  Future<Either<Failure, Map<String, dynamic>>> acceptInvite(String token);
  Future<Either<Failure, Map<String, dynamic>>> getGroupBalance(String groupId);
  Future<Either<Failure, Map<String, dynamic>>> transferOwnership(String groupId, String newOwnerId);
  Future<Either<Failure, Map<String, dynamic>>> updateMemberRole(String groupId, String memberId, String role);
}
