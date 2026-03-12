import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedef.dart';
import '../repositories/auth_repository.dart';

class ConfirmChangePasswordUseCase {
  final AuthRepository repository;

  ConfirmChangePasswordUseCase(this.repository);

  ResultFuture<String> call({
    required String otp,
    required String newPassword,
  }) async {
    return await repository.confirmChangePassword(
      otp: otp,
      newPassword: newPassword,
    );
  }
}
