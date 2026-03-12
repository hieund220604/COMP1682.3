import '../../../../core/utils/typedef.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class VerifyOTPUseCase {
  final AuthRepository _repository;

  VerifyOTPUseCase(this._repository);

  ResultFuture<User> call({
    required String email,
    required String otp,
  }) {
    return _repository.verifyOTP(email: email, otp: otp);
  }
}
