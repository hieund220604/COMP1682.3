import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/utils/token_manager.dart';
import '../../models/auth_response.dart';
import '../../models/user.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  requires2FA,
  error,
}

/// Fat Provider — calls DioClient directly, no use cases / repos / datasources.
class AuthProvider extends ChangeNotifier {
  final DioClient _dio;
  final TokenManager _tokenManager;
  final SharedPreferences _prefs;

  AuthProvider({
    required DioClient dio,
    required TokenManager tokenManager,
    required SharedPreferences prefs,
  })  : _dio = dio,
        _tokenManager = tokenManager,
        _prefs = prefs;

  // ─── State ──────────────────────────────────────────────
  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;
  String? _tempToken;

  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get tempToken => _tempToken;
  bool get isAuthenticated => _state == AuthState.authenticated && _user != null;
  bool get isLoading => _state == AuthState.loading;

  void _setState(AuthState s) {
    _state = s;
    notifyListeners();
  }

  void _setError(String msg) {
    _errorMessage = msg;
    _setState(AuthState.error);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ─── Login ──────────────────────────────────────────────
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    _setState(AuthState.loading);
    try {
      final resp = await _dio.post(
        ApiConstants.authLogin,
        data: {'email': email, 'password': password},
      );
      final authResp = AuthResponse.fromJson(resp.data);

      if (!authResp.success || authResp.data == null) {
        final msg = authResp.error?.message ?? 'Login failed';
        _setError(msg);
        return msg;
      }

      // 2FA required
      if (authResp.data!.requires2FA && authResp.data!.tempToken != null) {
        _tempToken = authResp.data!.tempToken;
        _setState(AuthState.requires2FA);
        return '2FA_REQUIRED';
      }

      // Save token + user
      await _saveAuthData(authResp.data!);
      return null; // success
    } catch (e) {
      final msg = _extractError(e);
      _setError(msg);
      return msg;
    }
  }

  bool _isGoogleInitialized = false;

  // ─── Login with Google ──────────────────────────────────
  Future<String?> loginWithGoogle() async {
    _setState(AuthState.loading);
    try {
      if (!_isGoogleInitialized) {
        await GoogleSignIn.instance.initialize(
          serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
        );
        _isGoogleInitialized = true;
      }
      
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null) {
        _setError('Không lấy được token xác thực từ Google');
        return 'Lỗi Token Google';
      }

      // Convert Google Credential to Firebase Credential
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase Auth
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      // Get the Firebase ID token
      final firebaseIdToken = await userCredential.user?.getIdToken();

      if (firebaseIdToken == null) {
        _setError('Lỗi: Không lấy được Firebase ID token');
        return 'Lỗi ID Token';
      }

      final resp = await _dio.post(
        '/auth/google-login',
        data: {'idToken': firebaseIdToken},
      );
      
      final root = resp.data;
      if (root == null) {
         _setError('Lỗi server');
         return 'Lỗi server';
      }
      
      // Attempt to parse standard format
      bool success = root['success'] == true;
      if (!success) {
         _setError(root['error']?['message'] ?? 'Đăng nhập Google thất bại');
         return 'Thất bại';
      }
      
      final authResp = AuthResponse.fromJson(resp.data);
      if (authResp.data == null) {
        _setError('Dữ liệu trả về bị lỗi');
        return 'Lỗi dữ liệu';
      }

      // Check 2FA if they somehow enabled it on a google account
      if (authResp.data!.requires2FA && authResp.data!.tempToken != null) {
        _tempToken = authResp.data!.tempToken;
        _setState(AuthState.requires2FA);
        return '2FA_REQUIRED';
      }

      // Save token + user
      await _saveAuthData(authResp.data!);
      return null; // success
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || 
          e.code == GoogleSignInExceptionCode.interrupted) {
        _setState(AuthState.unauthenticated);
        return 'Đăng nhập Google bị hủy';
      }
      final msg = 'Lỗi Google Sign In: ${e.toString()}';
      _setError(msg);
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      return msg;
    } catch (e) {
      final msg = _extractError(e);
      _setError(msg);
      // Ensure we clear GoogleSignIn session so they can try again if it fails
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {}
      return msg;
    }
  }

  // ─── Sign Up ────────────────────────────────────────────
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _setState(AuthState.loading);
    try {
      final resp = await _dio.post(
        ApiConstants.authSignup,
        data: {
          'email': email,
          'password': password,
          if (displayName != null) 'displayName': displayName,
        },
      );
      final authResp = AuthResponse.fromJson(resp.data);
      if (!authResp.success) {
        _setError(authResp.error?.message ?? 'Sign up failed');
        return false;
      }
      _setState(AuthState.unauthenticated);
      return true;
    } catch (e) {
      _setError(_extractError(e));
      return false;
    }
  }

  // ─── Verify OTP ─────────────────────────────────────────
  Future<bool> verifyOTP({required String email, required String otp}) async {
    _setState(AuthState.loading);
    try {
      final resp = await _dio.post(
        ApiConstants.authVerifyOtp,
        data: {'email': email, 'otp': otp},
      );
      final authResp = AuthResponse.fromJson(resp.data);
      if (!authResp.success || authResp.data == null) {
        _setError(authResp.error?.message ?? 'OTP verification failed');
        return false;
      }
      await _saveAuthData(authResp.data!);
      return true;
    } catch (e) {
      _setError(_extractError(e));
      return false;
    }
  }

  Future<bool> resendOTP({required String email}) async {
    clearError();
    try {
      await _dio.post(ApiConstants.authResendOtp, data: {'email': email});
      return true;
    } catch (e) {
      _setError(_extractError(e));
      return false;
    }
  }

  // ─── Logout ─────────────────────────────────────────────
  Future<void> logout() async {
    _setState(AuthState.loading);
    try {
      // Revoke refresh token server-side
      final refreshToken = await _tokenManager.getRefreshToken();
      if (refreshToken != null) {
        try {
          await _dio.post('/auth/logout', data: {'refreshToken': refreshToken});
        } catch (_) {} // Non-critical — always proceed with local cleanup
      }

      // Clear Google & Firebase sessions if any
      try {
        await GoogleSignIn.instance.signOut();
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      await _tokenManager.clearAll();
      _user = null;
      _setState(AuthState.unauthenticated);
    } catch (e) {
      _setError(_extractError(e));
    }
  }

  // ─── Get Current User ───────────────────────────────────
  Future<void> getCurrentUser({bool silent = false}) async {
    if (!silent) _setState(AuthState.loading);
    try {
      final resp = await _dio.get(ApiConstants.authMe);
      final root = resp.data;
      final data = root is Map<String, dynamic> ? root['data'] : null;
      final userJson =
          data is Map<String, dynamic> && data['user'] is Map<String, dynamic>
              ? data['user'] as Map<String, dynamic>
              : (data is Map<String, dynamic> ? data : <String, dynamic>{});

      _user = User.fromJson(userJson);
      _setState(AuthState.authenticated);
    } catch (e) {
      _errorMessage = _extractError(e);
      if (!silent) {
        _setState(AuthState.unauthenticated);
      } else {
        notifyListeners();
      }
    }
  }

  // ─── Update Profile ─────────────────────────────────────
  Future<bool> updateProfile({String? displayName, String? avatarUrl}) async {
    _setState(AuthState.loading);
    try {
      final data = <String, dynamic>{};
      if (displayName != null) data['displayName'] = displayName;
      if (avatarUrl != null) data['avatarUrl'] = avatarUrl;

      final resp = await _dio.patch(ApiConstants.authProfile, data: data);
      final root = resp.data;
      final respData = root is Map<String, dynamic> ? root['data'] : null;
      final userJson =
          respData is Map<String, dynamic> && respData['user'] is Map<String, dynamic>
              ? respData['user'] as Map<String, dynamic>
              : (respData is Map<String, dynamic> ? respData : <String, dynamic>{});

      _user = User.fromJson(userJson);
      _setState(AuthState.authenticated);
      return true;
    } catch (e) {
      _setError(_extractError(e));
      _setState(AuthState.authenticated);
      return false;
    }
  }

  // ─── Check Auth Status ──────────────────────────────────
  Future<void> checkAuthStatus() async {
    _setState(AuthState.loading);
    try {
      await getCurrentUser();
    } catch (_) {
      _setState(AuthState.unauthenticated);
    }
  }

  // ─── Change Password ───────────────────────────────────
  Future<bool> initiateChangePassword({
    required String oldPassword,
    required String newPassword,
    String? totpToken,
  }) async {
    _setState(AuthState.loading);
    try {
      await _dio.post('/auth/change-password/initiate', data: {
        'oldPassword': oldPassword,
        'newPassword': newPassword,
        if (totpToken != null) 'totpToken': totpToken,
      });
      _setState(AuthState.authenticated);
      return true;
    } catch (e) {
      _setError(_extractError(e));
      _setState(AuthState.authenticated);
      return false;
    }
  }

  Future<bool> confirmChangePassword({
    required String otp,
    required String newPassword,
  }) async {
    _setState(AuthState.loading);
    try {
      await _dio.post('/auth/change-password/confirm', data: {
        'otp': otp,
        'newPassword': newPassword,
      });
      _setState(AuthState.authenticated);
      return true;
    } catch (e) {
      _setError(_extractError(e));
      _setState(AuthState.authenticated);
      return false;
    }
  }

  // ─── Contact Us ─────────────────────────────────────────
  Future<bool> contactUs({required String subject, required String message}) async {
    _setState(AuthState.loading);
    try {
      await _dio.post('/auth/contact-us', data: {
        'subject': subject,
        'message': message,
      });
      _setState(AuthState.authenticated);
      return true;
    } catch (e) {
      _setError(_extractError(e));
      _setState(AuthState.authenticated);
      return false;
    }
  }

  // ─── Forgot Password ────────────────────────────────────
  Future<bool> forgotPassword({required String email}) async {
    _setState(AuthState.loading);
    try {
      await _dio.post(ApiConstants.authForgotPassword, data: {'email': email});
      _setState(AuthState.unauthenticated);
      return true;
    } catch (e) {
      _setError(_extractError(e));
      _setState(AuthState.unauthenticated);
      return false;
    }
  }

  Future<String?> verifyResetOTP({required String email, required String otp}) async {
    _setState(AuthState.loading);
    try {
      final resp = await _dio.post(
        ApiConstants.authVerifyResetOtp,
        data: {'email': email, 'otp': otp},
      );
      _setState(AuthState.unauthenticated);
      
      final data = resp.data['data'];
      if (data is Map<String, dynamic> && data['resetToken'] != null) {
        return data['resetToken'] as String;
      }
      return null;
    } catch (e) {
      _setError(_extractError(e));
      _setState(AuthState.unauthenticated);
      return null;
    }
  }

  Future<bool> resetPasswordWithToken({
    required String resetToken,
    required String newPassword,
  }) async {
    _setState(AuthState.loading);
    try {
      await _dio.post(
        ApiConstants.authResetPasswordToken,
        data: {'resetToken': resetToken, 'newPassword': newPassword},
      );
      _setState(AuthState.unauthenticated);
      return true;
    } catch (e) {
      _setError(_extractError(e));
      _setState(AuthState.unauthenticated);
      return false;
    }
  }

  // ─── 2FA ────────────────────────────────────────────────
  Future<String?> verify2FALogin({required String token}) async {
    if (_tempToken == null) return 'No pending 2FA session';
    _errorMessage = null;
    notifyListeners();

    try {
      final resp = await _dio.post(
        ApiConstants.twoFactorVerify,
        data: {'tempToken': _tempToken, 'token': token},
      );
      final authResp = AuthResponse.fromJson(resp.data);
      if (!authResp.success || authResp.data == null) {
        _errorMessage = authResp.error?.message ?? '2FA verification failed';
        _state = AuthState.requires2FA;
        notifyListeners();
        return _errorMessage;
      }
      await _saveAuthData(authResp.data!);
      _tempToken = null;
      return null;
    } catch (e) {
      _errorMessage = _extractError(e);
      _state = AuthState.requires2FA;
      notifyListeners();
      return _errorMessage;
    }
  }

  Future<Map<String, dynamic>?> setup2FA() async {
    try {
      final resp = await _dio.post(ApiConstants.twoFactorSetup);
      return resp.data['data'] as Map<String, dynamic>;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> verifySetup2FA({required String token}) async {
    try {
      final resp = await _dio.post(
        ApiConstants.twoFactorVerifySetup,
        data: {'token': token},
      );
      getCurrentUser(silent: true);
      return resp.data['data'] as Map<String, dynamic>;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return null;
    }
  }

  Future<bool> disable2FA({required String token}) async {
    try {
      await _dio.post(ApiConstants.twoFactorDisable, data: {'token': token});
      getCurrentUser(silent: true);
      return true;
    } catch (e) {
      _errorMessage = _extractError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> get2FAStatus() async {
    try {
      final resp = await _dio.get(ApiConstants.twoFactorStatus);
      final data = resp.data['data'];
      return data is Map<String, dynamic>
          ? data['twoFactorEnabled'] == true
          : false;
    } catch (_) {
      return false;
    }
  }

  // ─── Onboarding ─────────────────────────────────────────
  Future<void> setShowOnboardingOnLogin(bool show) async {
    await _prefs.setBool('show_onboarding_on_login', show);
  }

  Future<bool> getShowOnboardingOnLogin() async {
    return _prefs.getBool('show_onboarding_on_login') ?? true;
  }

  bool shouldShowOnboarding() {
    return _prefs.getBool('show_onboarding_on_login') ?? true;
  }

  // ─── Helpers ────────────────────────────────────────────
  Future<void> _saveAuthData(AuthData data) async {
    if (data.token != null) {
      await _tokenManager.saveToken(data.token!);
    }
    if (data.refreshToken != null) {
      await _tokenManager.saveRefreshToken(data.refreshToken!);
    }
    if (data.user != null) {
      await _tokenManager.saveUserInfo(
        userId: data.user!.id,
        email: data.user!.email,
      );
      _user = data.user;
    }
    _setState(AuthState.authenticated);
  }

  String _extractError(dynamic e) {
    if (e is Exception) return e.toString().replaceFirst('Exception: ', '');
    return e.toString();
  }
}
