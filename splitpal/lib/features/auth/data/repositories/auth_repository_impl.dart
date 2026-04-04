import 'package:dartz/dartz.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/token_manager.dart';
import '../../../../core/utils/typedef.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_data_source.dart';
import '../models/login_request.dart';
import '../models/signup_request.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final TokenManager _tokenManager;

  AuthRepositoryImpl({
    required AuthRemoteDataSource remoteDataSource,
    required TokenManager tokenManager,
  })  : _remoteDataSource = remoteDataSource,
        _tokenManager = tokenManager;

  @override
  ResultFuture<User> login({
    required String email,
    required String password,
  }) async {
    try {
      final request = LoginRequest(email: email, password: password);
      final response = await _remoteDataSource.login(request);

      if (!response.success || response.data == null) {
        return Left(
          ServerFailure(
            message: response.error?.message ?? 'Login failed',
          ),
        );
      }

      // Check if 2FA is required
      if (response.data!.requires2FA && response.data!.tempToken != null) {
        return Left(
          TwoFactorRequiredFailure(tempToken: response.data!.tempToken!),
        );
      }

      // Save token
      if (response.data!.token != null) {
        await _tokenManager.saveToken(response.data!.token!);
      }

      // Save user info
      if (response.data!.user != null) {
        await _tokenManager.saveUserInfo(
          userId: response.data!.user!.id,
          email: response.data!.user!.email,
        );
      }

      return Right(response.data!.user!.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(message: e.message));
    } catch (e) {
      final msg = (e is TypeError || e is FormatException)
          ? 'Phản hồi máy chủ không hợp lệ.'
          : 'Đăng nhập thất bại. Vui lòng thử lại.';
      return Left(UnknownFailure(message: msg));
    }
  }

  @override
  ResultFuture<String> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final request = SignUpRequest(
        email: email,
        password: password,
        displayName: displayName,
      );
      final response = await _remoteDataSource.signUp(request);

      if (!response.success) {
        return Left(
          ServerFailure(
            message: response.error?.message ?? 'Sign up failed',
          ),
        );
      }

      return Right(response.message);
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } on TypeError catch (_) {
      // Be tolerant to schema drifts: backend returned success but unexpected shape.
      return Right('Account created. Please verify your email.');
    } on FormatException catch (_) {
      return Right('Account created. Please verify your email.');
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<User> verifyOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _remoteDataSource.verifyOTP(email, otp);

      if (!response.success || response.data == null) {
        return Left(
          ValidationFailure(
            message: response.error?.message ?? 'OTP verification failed',
          ),
        );
      }

      // Save token
      if (response.data!.token != null) {
        await _tokenManager.saveToken(response.data!.token!);
      }

      // Save user info
      if (response.data!.user != null) {
        await _tokenManager.saveUserInfo(
          userId: response.data!.user!.id,
          email: response.data!.user!.email,
        );
      }

      return Right(response.data!.user!.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      final msg = (e is TypeError || e is FormatException)
          ? 'Invalid response from server.'
          : e.toString();
      return Left(UnknownFailure(message: msg));
    }
  }

  @override
  ResultFuture<void> resendOTP({required String email}) async {
    try {
      final response = await _remoteDataSource.resendOTP(email);

      if (!response.success) {
        return Left(
          ServerFailure(
            message: response.error?.message ?? 'Failed to resend OTP',
          ),
        );
      }

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      final msg = (e is TypeError || e is FormatException)
          ? 'Invalid response from server.'
          : e.toString();
      return Left(UnknownFailure(message: msg));
    }
  }

  @override
  ResultFuture<void> forgotPassword({required String email}) async {
    try {
      final response = await _remoteDataSource.forgotPassword(email);

      if (!response.success) {
        return Left(
          ServerFailure(
            message: response.error?.message ?? 'Failed to send reset email',
          ),
        );
      }

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      final msg = (e is TypeError || e is FormatException)
          ? 'Invalid response from server.'
          : e.toString();
      return Left(UnknownFailure(message: msg));
    }
  }

  @override
  ResultFuture<String> verifyResetOTP({
    required String email,
    required String otp,
  }) async {
    try {
      final response = await _remoteDataSource.verifyResetOTP(email, otp);

      if (!response.success || response.data?.resetToken == null) {
        return Left(
          ValidationFailure(
            message: response.error?.message ?? 'Invalid OTP',
          ),
        );
      }

      return Right(response.data!.resetToken!);
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      final msg = (e is TypeError || e is FormatException)
          ? 'Invalid response from server.'
          : e.toString();
      return Left(UnknownFailure(message: msg));
    }
  }

  @override
  ResultFuture<void> resetPasswordWithToken({
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      final response = await _remoteDataSource.resetPasswordWithToken(
        resetToken,
        newPassword,
      );

      if (!response.success) {
        return Left(
          ServerFailure(
            message: response.error?.message ?? 'Failed to reset password',
          ),
        );
      }

      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      final msg = (e is TypeError || e is FormatException)
          ? 'Invalid response from server.'
          : e.toString();
      return Left(UnknownFailure(message: msg));
    }
  }

  @override
  ResultFuture<User> getCurrentUser() async {
    try {
      final userModel = await _remoteDataSource.getCurrentUser();
      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on UnauthorizedException catch (e) {
      return Left(UnauthorizedFailure(message: e.message));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      final msg = (e is TypeError || e is FormatException)
          ? 'Invalid response from server.'
          : e.toString();
      return Left(UnknownFailure(message: msg));
    }
  }

  @override
  ResultFuture<User> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    try {
      final userModel = await _remoteDataSource.updateProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
      );
      return Right(userModel.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(
        message: e.message,
        statusCode: e.statusCode,
      ));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      final msg = (e is TypeError || e is FormatException)
          ? 'Phản hồi không hợp lệ từ máy chủ.'
          : e.toString();
      return Left(UnknownFailure(message: msg));
    }
  }

  @override
  ResultFuture<void> logout() async {
    try {
      await _tokenManager.clearAll();
      return const Right(null);
    } catch (e) {
      final msg = (e is TypeError || e is FormatException)
          ? 'Invalid response from server.'
          : e.toString();
      return Left(UnknownFailure(message: msg));
    }
  }

  @override
  ResultFuture<String> initiateChangePassword({
    required String oldPassword,
    required String newPassword,
    String? totpToken,
  }) async {
    try {
      final message = await _remoteDataSource.initiateChangePassword(
        oldPassword,
        newPassword,
        totpToken: totpToken,
      );
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<String> confirmChangePassword({
    required String otp,
    required String newPassword,
  }) async {
    try {
      final message = await _remoteDataSource.confirmChangePassword(
        otp,
        newPassword,
      );
      return Right(message);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<String> contactUs({
    required String subject,
    required String message,
  }) async {
    try {
      final responseMessage = await _remoteDataSource.contactUs(subject, message);
      return Right(responseMessage);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  // ─── 2FA ─────────────────────────────────────────────────────────────

  @override
  ResultFuture<Map<String, dynamic>> setup2FA() async {
    try {
      final data = await _remoteDataSource.setup2FA();
      return Right(data);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<Map<String, dynamic>> verifySetup2FA({required String token}) async {
    try {
      final data = await _remoteDataSource.verifySetup2FA(token);
      return Right(data);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<User> verify2FALogin({
    required String tempToken,
    required String token,
  }) async {
    try {
      final response = await _remoteDataSource.verify2FALogin(tempToken, token);

      if (!response.success || response.data == null) {
        return Left(
          ServerFailure(message: response.error?.message ?? '2FA verification failed'),
        );
      }

      // Save token
      if (response.data!.token != null) {
        await _tokenManager.saveToken(response.data!.token!);
      }

      // Save user info
      if (response.data!.user != null) {
        await _tokenManager.saveUserInfo(
          userId: response.data!.user!.id,
          email: response.data!.user!.email,
        );
      }

      return Right(response.data!.user!.toEntity());
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<void> disable2FA({required String token}) async {
    try {
      await _remoteDataSource.disable2FA(token);
      return const Right(null);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  ResultFuture<bool> get2FAStatus() async {
    try {
      final enabled = await _remoteDataSource.get2FAStatus();
      return Right(enabled);
    } on ServerException catch (e) {
      return Left(ServerFailure(message: e.message, statusCode: e.statusCode));
    } on NetworkException catch (e) {
      return Left(NetworkFailure(message: e.message));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}
