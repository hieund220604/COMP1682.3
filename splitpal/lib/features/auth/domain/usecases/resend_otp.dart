import '../../../../core/utils/typedef.dart';
import '../repositories/auth_repository.dart';

class ResendOTPUseCase {
  final AuthRepository _repository;

  ResendOTPUseCase(this._repository);

  ResultFuture<void> call({required String email}) {
    return _repository.resendOTP(email: email);
  }
}
