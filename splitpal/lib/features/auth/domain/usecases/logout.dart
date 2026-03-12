import '../../../../core/utils/typedef.dart';
import '../repositories/auth_repository.dart';

class LogoutUseCase {
  final AuthRepository _repository;

  LogoutUseCase(this._repository);

  ResultVoid call() {
    return _repository.logout();
  }
}
