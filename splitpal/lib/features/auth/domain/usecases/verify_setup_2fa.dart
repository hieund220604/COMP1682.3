import '../../../../core/utils/typedef.dart';
import '../repositories/auth_repository.dart';

class VerifySetup2FAUseCase {
  final AuthRepository _repository;

  VerifySetup2FAUseCase(this._repository);

  ResultFuture<Map<String, dynamic>> call({required String token}) {
    return _repository.verifySetup2FA(token: token);
  }
}
