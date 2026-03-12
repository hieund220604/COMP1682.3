import '../../../../core/utils/typedef.dart';
import '../repositories/auth_repository.dart';

class Get2FAStatusUseCase {
  final AuthRepository _repository;

  Get2FAStatusUseCase(this._repository);

  ResultFuture<bool> call() {
    return _repository.get2FAStatus();
  }
}
