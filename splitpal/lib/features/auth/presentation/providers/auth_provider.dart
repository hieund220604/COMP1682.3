import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/login.dart';
import '../../domain/usecases/logout.dart';
import '../../domain/usecases/signup.dart';
import '../../domain/usecases/update_profile.dart';
import '../../domain/usecases/verify_otp.dart';
import '../../domain/usecases/resend_otp.dart';
import '../../domain/usecases/initiate_change_password.dart';
import '../../domain/usecases/confirm_change_password.dart';
import '../../domain/usecases/contact_us.dart';
import '../../domain/usecases/setup_2fa.dart';
import '../../domain/usecases/verify_setup_2fa.dart';
import '../../domain/usecases/verify_2fa_login.dart';
import '../../domain/usecases/disable_2fa.dart';
import '../../domain/usecases/get_2fa_status.dart';
import '../../../../core/di/injection_container.dart';

enum AuthState {
  initial,
  loading,
  authenticated,
  unauthenticated,
  requires2FA,
  error,
}

class AuthProvider extends ChangeNotifier {
  final LoginUseCase _loginUseCase;
  final SignUpUseCase _signUpUseCase;
  final VerifyOTPUseCase _verifyOTPUseCase;
  final ResendOTPUseCase _resendOTPUseCase;
  final LogoutUseCase _logoutUseCase;
  final GetCurrentUserUseCase _getCurrentUserUseCase;
  final UpdateProfileUseCase _updateProfileUseCase;
  final InitiateChangePasswordUseCase _initiateChangePasswordUseCase;
  final ConfirmChangePasswordUseCase _confirmChangePasswordUseCase;
  final ContactUsUseCase _contactUsUseCase;
  final Setup2FAUseCase _setup2FAUseCase;
  final VerifySetup2FAUseCase _verifySetup2FAUseCase;
  final Verify2FALoginUseCase _verify2FALoginUseCase;
  final Disable2FAUseCase _disable2FAUseCase;
  final Get2FAStatusUseCase _get2FAStatusUseCase;

  AuthProvider({
    required LoginUseCase loginUseCase,
    required SignUpUseCase signUpUseCase,
    required VerifyOTPUseCase verifyOTPUseCase,
    required ResendOTPUseCase resendOTPUseCase,
    required LogoutUseCase logoutUseCase,
    required GetCurrentUserUseCase getCurrentUserUseCase,
    required UpdateProfileUseCase updateProfileUseCase,
    required InitiateChangePasswordUseCase initiateChangePasswordUseCase,
    required ConfirmChangePasswordUseCase confirmChangePasswordUseCase,
    required ContactUsUseCase contactUsUseCase,
    required Setup2FAUseCase setup2FAUseCase,
    required VerifySetup2FAUseCase verifySetup2FAUseCase,
    required Verify2FALoginUseCase verify2FALoginUseCase,
    required Disable2FAUseCase disable2FAUseCase,
    required Get2FAStatusUseCase get2FAStatusUseCase,
  })  : _loginUseCase = loginUseCase,
        _signUpUseCase = signUpUseCase,
        _verifyOTPUseCase = verifyOTPUseCase,
        _resendOTPUseCase = resendOTPUseCase,
        _logoutUseCase = logoutUseCase,
        _getCurrentUserUseCase = getCurrentUserUseCase,
        _updateProfileUseCase = updateProfileUseCase,
        _initiateChangePasswordUseCase = initiateChangePasswordUseCase,
        _confirmChangePasswordUseCase = confirmChangePasswordUseCase,
        _contactUsUseCase = contactUsUseCase,
        _setup2FAUseCase = setup2FAUseCase,
        _verifySetup2FAUseCase = verifySetup2FAUseCase,
        _verify2FALoginUseCase = verify2FALoginUseCase,
        _disable2FAUseCase = disable2FAUseCase,
        _get2FAStatusUseCase = get2FAStatusUseCase;

  // State
  AuthState _state = AuthState.initial;
  User? _user;
  String? _errorMessage;
  String? _tempToken; // Temp JWT for 2FA login flow

  // Getters
  AuthState get state => _state;
  User? get user => _user;
  String? get errorMessage => _errorMessage;
  String? get tempToken => _tempToken;
  bool get isAuthenticated => _state == AuthState.authenticated && _user != null;
  bool get isLoading => _state == AuthState.loading;

  // Set state helper
  void _setState(AuthState newState) {
    _state = newState;
    notifyListeners();
  }

  void _setError(String message) {
    _errorMessage = message;
    _setState(AuthState.error);
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Login
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    _setState(AuthState.loading);

    final result = await _loginUseCase(
      email: email,
      password: password,
    );

    return result.fold(
      (failure) {
        if (failure is TwoFactorRequiredFailure) {
          _tempToken = failure.tempToken;
          _setState(AuthState.requires2FA);
          return '2FA_REQUIRED';
        }
        final errorMsg = failure.message;
        _setError(errorMsg);
        return errorMsg;
      },
      (user) {
        _user = user;
        _setState(AuthState.authenticated);
        return null;
      },
    );
  }

  // Sign Up
  Future<bool> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    _setState(AuthState.loading);

    final result = await _signUpUseCase(
      email: email,
      password: password,
      displayName: displayName,
    );

    return result.fold(
      (failure) {
        _setError(failure.message ?? 'Sign up failed');
        return false;
      },
      (message) {
        _setState(AuthState.unauthenticated);
        return true;
      },
    );
  }

  // Verify OTP
  Future<bool> verifyOTP({
    required String email,
    required String otp,
  }) async {
    _setState(AuthState.loading);

    final result = await _verifyOTPUseCase(
      email: email,
      otp: otp,
    );

    return result.fold(
      (failure) {
        _setError(failure.message ?? 'OTP verification failed');
        return false;
      },
      (user) {
        _user = user;
        _setState(AuthState.authenticated);
        return true;
      },
    );
  }

  Future<bool> resendOTP({required String email}) async {
    clearError();
    final result = await _resendOTPUseCase(email: email);
    return result.fold(
      (failure) {
        _setError(failure.message ?? 'Failed to resend OTP');
        return false;
      },
      (_) => true,
    );
  }

  // Logout
  Future<void> logout() async {
    _setState(AuthState.loading);

    final result = await _logoutUseCase();

    result.fold(
      (failure) => _setError(failure.message ?? 'Logout failed'),
      (_) {
        _user = null;
        _setState(AuthState.unauthenticated);
      },
    );
  }

  // Get Current User
  Future<void> getCurrentUser({bool silent = false}) async {
    // Avoid forcing a full-app rebuild when we just need fresh user data.
    if (!silent) {
      _setState(AuthState.loading);
    }

    final result = await _getCurrentUserUseCase();

    result.fold(
      (failure) {
        _errorMessage = failure.message;

        if (!silent || failure is UnauthorizedFailure) {
          _setState(AuthState.unauthenticated);
        } else {
          // Keep current auth view; just notify listeners about the error.
          notifyListeners();
        }
      },
      (user) {
        _user = user;
        // Stay in authenticated state to avoid navigation reset loops.
        _setState(AuthState.authenticated);
      },
    );
  }

  // Update Profile
  Future<bool> updateProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    _setState(AuthState.loading);

    final result = await _updateProfileUseCase(
      displayName: displayName,
      avatarUrl: avatarUrl,
    );

    return result.fold(
      (failure) {
        _setError(failure.message ?? 'Update profile failed');
        _setState(AuthState.authenticated); // Remain authenticated
        return false;
      },
      (user) {
        _user = user;
        _setState(AuthState.authenticated);
        return true;
      },
    );
  }

  // Initialize - Check if user is logged in
  Future<void> initialize() async {
    try {
      await getCurrentUser();
    } catch (e) {
      _setState(AuthState.unauthenticated);
    }
  }

  // Check auth status on app start
  Future<void> checkAuthStatus() async {
    _setState(AuthState.loading);
    
    try {
      await getCurrentUser();
    } catch (e) {
      _setState(AuthState.unauthenticated);
    }
  }

  // Change Password - Initiate
  Future<bool> initiateChangePassword({
    required String oldPassword,
    required String newPassword,
    String? totpToken,
  }) async {
    _setState(AuthState.loading);
    
    final result = await _initiateChangePasswordUseCase(
      oldPassword: oldPassword,
      newPassword: newPassword,
      totpToken: totpToken,
    );

    return result.fold(
      (failure) {
        _setError(failure.message ?? 'Failed to initiate change password');
        _setState(AuthState.authenticated);
        return false;
      },
      (message) {
        _setState(AuthState.authenticated);
        return true;
      },
    );
  }

  // Change Password - Confirm
  Future<bool> confirmChangePassword({
    required String otp,
    required String newPassword,
  }) async {
    _setState(AuthState.loading);
    
    final result = await _confirmChangePasswordUseCase(
      otp: otp,
      newPassword: newPassword,
    );

    return result.fold(
      (failure) {
        _setError(failure.message ?? 'Failed to confirm change password');
        _setState(AuthState.authenticated);
        return false;
      },
      (message) {
        _setState(AuthState.authenticated);
        return true;
      },
    );
  }

  // Contact Us
  Future<bool> contactUs({
    required String subject,
    required String message,
  }) async {
    _setState(AuthState.loading);
    
    final result = await _contactUsUseCase(
      subject: subject,
      message: message,
    );

    return result.fold(
      (failure) {
        _setError(failure.message ?? 'Failed to send message');
        _setState(AuthState.authenticated);
        return false;
      },
      (message) {
        _setState(AuthState.authenticated);
        return true;
      },
    );
  }

  // ─── 2FA ─────────────────────────────────────────────────────────────

  /// Verify 2FA code during login flow.
  /// Call this after login returns '2FA_REQUIRED'.
  Future<String?> verify2FALogin({required String token}) async {
    if (_tempToken == null) {
      return 'No pending 2FA session';
    }
    // Don't set loading state here — it would unmount the Verify2FAPage
    // via the Consumer in main.dart
    _errorMessage = null;
    notifyListeners();

    final result = await _verify2FALoginUseCase(
      tempToken: _tempToken!,
      token: token,
    );

    return result.fold(
      (failure) {
        // Keep requires2FA state so the Verify2FAPage stays visible
        _errorMessage = failure.message;
        _state = AuthState.requires2FA;
        notifyListeners();
        return failure.message;
      },
      (user) {
        _user = user;
        _tempToken = null;
        _setState(AuthState.authenticated);
        return null;
      },
    );
  }

  /// Setup 2FA – returns { qrCodeUrl, manualKey }.
  Future<Map<String, dynamic>?> setup2FA() async {
    final result = await _setup2FAUseCase();
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return null;
      },
      (data) => data,
    );
  }

  /// Confirm 2FA setup with TOTP code – returns { backupCodes: [...] }.
  Future<Map<String, dynamic>?> verifySetup2FA({required String token}) async {
    final result = await _verifySetup2FAUseCase(token: token);
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return null;
      },
      (data) {
        // Refresh user to reflect twoFactorEnabled = true
        getCurrentUser(silent: true);
        return data;
      },
    );
  }

  /// Disable 2FA with TOTP code.
  Future<bool> disable2FA({required String token}) async {
    final result = await _disable2FAUseCase(token: token);
    return result.fold(
      (failure) {
        _errorMessage = failure.message;
        notifyListeners();
        return false;
      },
      (_) {
        // Refresh user to reflect twoFactorEnabled = false
        getCurrentUser(silent: true);
        return true;
      },
    );
  }

  /// Check whether current user has 2FA enabled.
  Future<bool> get2FAStatus() async {
    final result = await _get2FAStatusUseCase();
    return result.fold(
      (failure) => false,
      (enabled) => enabled,
    );
  }

  /// Set whether to show onboarding on login
  Future<void> setShowOnboardingOnLogin(bool show) async {
    try {
      final prefs = sl<SharedPreferences>();
      await prefs.setBool('show_onboarding_on_login', show);
      // Don't call notifyListeners() - this setting takes effect on next login
    } catch (e) {
      print('Error setting onboarding preference: $e');
    }
  }

  /// Get whether to show onboarding on login
  Future<bool> getShowOnboardingOnLogin() async {
    try {
      final prefs = sl<SharedPreferences>();
      return prefs.getBool('show_onboarding_on_login') ?? true; // Default to true
    } catch (e) {
      print('Error getting onboarding preference: $e');
      return true;
    }
  }

  /// Sync method to get cached onboarding preference (for startup routing)
  bool shouldShowOnboarding() {
    try {
      final prefs = sl<SharedPreferences>();
      return prefs.getBool('show_onboarding_on_login') ?? true;
    } catch (e) {
      return true;
    }
  }
}
