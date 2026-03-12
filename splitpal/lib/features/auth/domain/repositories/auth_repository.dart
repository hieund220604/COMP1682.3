import '../../../../core/utils/typedef.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  ResultFuture<User> login({
    required String email,
    required String password,
  });

  ResultFuture<String> signUp({
    required String email,
    required String password,
    String? displayName,
  });

  ResultFuture<User> verifyOTP({
    required String email,
    required String otp,
  });

  ResultFuture<void> resendOTP({
    required String email,
  });

  ResultFuture<void> forgotPassword({
    required String email,
  });

  ResultFuture<String> verifyResetOTP({
    required String email,
    required String otp,
  });

  ResultFuture<void> resetPasswordWithToken({
    required String resetToken,
    required String newPassword,
  });

  ResultFuture<User> getCurrentUser();

  ResultFuture<User> updateProfile({
    String? displayName,
    String? avatarUrl,
  });

  ResultFuture<void> logout();

  ResultFuture<String> initiateChangePassword({
    required String oldPassword,
    required String newPassword,
    String? totpToken,
  });

  ResultFuture<String> confirmChangePassword({
    required String otp,
    required String newPassword,
  });

  ResultFuture<String> contactUs({
    required String subject,
    required String message,
  });

  ResultFuture<Map<String, dynamic>> getGlobalDebtSummary();

  // 2FA methods
  ResultFuture<Map<String, dynamic>> setup2FA();
  ResultFuture<Map<String, dynamic>> verifySetup2FA({required String token});
  ResultFuture<User> verify2FALogin({required String tempToken, required String token});
  ResultFuture<void> disable2FA({required String token});
  ResultFuture<bool> get2FAStatus();
}
