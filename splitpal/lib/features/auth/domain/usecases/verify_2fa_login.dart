import '../../../../core/utils/typedef.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class Verify2FALoginUseCase {
  final AuthRepository _repository;

  Verify2FALoginUseCase(this._repository);

  ResultFuture<User> call({
    required String tempToken,
    required String token,
  }) {
    return _repository.verify2FALogin(tempToken: tempToken, token: token);
  }
}
