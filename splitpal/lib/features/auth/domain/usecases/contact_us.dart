import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/typedef.dart';
import '../repositories/auth_repository.dart';

class ContactUsUseCase {
  final AuthRepository repository;

  ContactUsUseCase(this.repository);

  ResultFuture<String> call({
    required String subject,
    required String message,
  }) async {
    return await repository.contactUs(
      subject: subject,
      message: message,
    );
  }
}
