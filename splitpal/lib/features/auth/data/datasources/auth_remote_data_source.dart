import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../models/auth_response.dart';
import '../models/login_request.dart';
import '../models/signup_request.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponse> signUp(SignUpRequest request);
  Future<AuthResponse> login(LoginRequest request);
  Future<AuthResponse> verifyOTP(String email, String otp);
  Future<AuthResponse> resendOTP(String email);
  Future<AuthResponse> forgotPassword(String email);
  Future<AuthResponse> verifyResetOTP(String email, String otp);
  Future<AuthResponse> resetPasswordWithToken(String resetToken, String newPassword);
  Future<UserModel> getCurrentUser();
  Future<UserModel> updateProfile({String? displayName, String? avatarUrl});
  Future<String> initiateChangePassword(String oldPassword, String newPassword, {String? totpToken});
  Future<String> confirmChangePassword(String otp, String newPassword);
  Future<String> contactUs(String subject, String message);

  // 2FA methods
  Future<Map<String, dynamic>> setup2FA();
  Future<Map<String, dynamic>> verifySetup2FA(String token);
  Future<AuthResponse> verify2FALogin(String tempToken, String token);
  Future<void> disable2FA(String token);
  Future<bool> get2FAStatus();
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final DioClient _dioClient;

  AuthRemoteDataSourceImpl({required DioClient dioClient})
      : _dioClient = dioClient;

  @override
  Future<AuthResponse> signUp(SignUpRequest request) async {
    final response = await _dioClient.post(
      ApiConstants.authSignup,
      data: request.toJson(),
    );

    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _dioClient.post(
      ApiConstants.authLogin,
      data: request.toJson(),
    );

    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<AuthResponse> verifyOTP(String email, String otp) async {
    final response = await _dioClient.post(
      ApiConstants.authVerifyOtp,
      data: {
        'email': email,
        'otp': otp,
      },
    );

    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<AuthResponse> resendOTP(String email) async {
    final response = await _dioClient.post(
      ApiConstants.authResendOtp,
      data: {'email': email},
    );

    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<AuthResponse> forgotPassword(String email) async {
    final response = await _dioClient.post(
      ApiConstants.authForgotPassword,
      data: {'email': email},
    );

    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<AuthResponse> verifyResetOTP(String email, String otp) async {
    final response = await _dioClient.post(
      ApiConstants.authVerifyResetOtp,
      data: {
        'email': email,
        'otp': otp,
      },
    );

    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<AuthResponse> resetPasswordWithToken(
    String resetToken,
    String newPassword,
  ) async {
    final response = await _dioClient.post(
      ApiConstants.authResetPasswordToken,
      data: {
        'resetToken': resetToken,
        'newPassword': newPassword,
      },
    );

    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<UserModel> getCurrentUser() async {
    final response = await _dioClient.get(ApiConstants.authMe);
    final root = response.data;
    final data = root is Map<String, dynamic> ? root['data'] : null;
    final userJson = data is Map<String, dynamic> && data['user'] is Map<String, dynamic>
        ? data['user'] as Map<String, dynamic>
        : (data is Map<String, dynamic> ? data : <String, dynamic>{});

    return UserModel.fromJson(userJson);
  }

  @override
  Future<UserModel> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['displayName'] = displayName;
    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;

    final response = await _dioClient.patch(
      ApiConstants.authProfile,
      data: data,
    );
    final root = response.data;
    final responseData = root is Map<String, dynamic> ? root['data'] : null;
    final userJson = responseData is Map<String, dynamic> && responseData['user'] is Map<String, dynamic>
        ? responseData['user'] as Map<String, dynamic>
        : (responseData is Map<String, dynamic> ? responseData : <String, dynamic>{});

    return UserModel.fromJson(userJson);
  }
  @override
  Future<String> initiateChangePassword(String oldPassword, String newPassword, {String? totpToken}) async {
    final response = await _dioClient.post(
      '/auth/change-password/initiate',
      data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        if (totpToken != null) 'totpToken': totpToken,
      },
    );
    return response.data['message'];
  }

  @override
  Future<String> confirmChangePassword(String otp, String newPassword) async {
    final response = await _dioClient.post(
      '/auth/change-password/confirm',
      data: {
        'otp': otp,
        'newPassword': newPassword,
      },
    );
    return response.data['message'];
  }

  @override
  Future<String> contactUs(String subject, String message) async {
    final response = await _dioClient.post(
      '/auth/contact-us',
      data: {
        'subject': subject,
        'message': message,
      },
    );
    return response.data['message'];
  }

  // ─── 2FA ─────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> setup2FA() async {
    final response = await _dioClient.post(ApiConstants.twoFactorSetup);
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<Map<String, dynamic>> verifySetup2FA(String token) async {
    final response = await _dioClient.post(
      ApiConstants.twoFactorVerifySetup,
      data: {'token': token},
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  @override
  Future<AuthResponse> verify2FALogin(String tempToken, String token) async {
    final response = await _dioClient.post(
      ApiConstants.twoFactorVerify,
      data: {'tempToken': tempToken, 'token': token},
    );
    return AuthResponse.fromJson(response.data);
  }

  @override
  Future<void> disable2FA(String token) async {
    await _dioClient.post(
      ApiConstants.twoFactorDisable,
      data: {'token': token},
    );
  }

  @override
  Future<bool> get2FAStatus() async {
    final response = await _dioClient.get(ApiConstants.twoFactorStatus);
    final data = response.data['data'];
    return data is Map<String, dynamic>
        ? data['twoFactorEnabled'] == true
        : false;
  }
}
