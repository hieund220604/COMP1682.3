import '../../../../core/utils/typedef.dart';
import '../repositories/auth_repository.dart';

class Setup2FAUseCase {
  final AuthRepository _repository;

  Setup2FAUseCase(this._repository);

  ResultFuture<Map<String, dynamic>> call() {
    return _repository.setup2FA();
  }
}
