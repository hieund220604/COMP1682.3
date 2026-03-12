import '../../../../core/utils/typedef.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class UpdateProfileUseCase {
  final AuthRepository _repository;

  UpdateProfileUseCase(this._repository);

  ResultFuture<User> call({
    String? displayName,
    String? avatarUrl,
  }) {
    return _repository.updateProfile(
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
  }
}
