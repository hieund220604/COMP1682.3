import '../../../../core/utils/typedef.dart';
import '../repositories/auth_repository.dart';

class Disable2FAUseCase {
  final AuthRepository _repository;

  Disable2FAUseCase(this._repository);

  ResultFuture<void> call({required String token}) {
    return _repository.disable2FA(token: token);
  }
}
