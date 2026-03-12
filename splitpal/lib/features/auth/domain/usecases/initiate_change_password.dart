import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedef.dart';
import '../repositories/auth_repository.dart';

class InitiateChangePasswordUseCase {
  final AuthRepository repository;

  InitiateChangePasswordUseCase(this.repository);

  ResultFuture<String> call({
    required String oldPassword,
    required String newPassword,
    String? totpToken,
  }) async {
    return await repository.initiateChangePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
      totpToken: totpToken,
    );
  }
}
