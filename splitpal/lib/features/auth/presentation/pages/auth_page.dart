import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/features/auth/auth_provider.dart';
import 'verify_otp_page.dart';
import 'verify_2fa_page.dart';
import 'forgot_password_page.dart';
import 'package:splitpal/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:splitpal/features/home/presentation/pages/home_shell_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool _isLoginMode = true;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _displayNameController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final authProvider = context.read<AuthProvider>();
    final normalizedEmail = _emailController.text.trim().toLowerCase();
    authProvider.clearError();
    
    if (_isLoginMode) {
      // Login
      final error = await authProvider.login(
        email: normalizedEmail,
        password: _passwordController.text,
      );
      
      if (!mounted) return;

      if (error == '2FA_REQUIRED') {
        // Navigate to 2FA verification page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const Verify2FAPage(),
          ),
        );
        return;
      }

      if (authProvider.isAuthenticated) {
        if (authProvider.shouldShowOnboarding()) {
          Navigator.pushReplacementNamed(context, OnboardingPage.routeName);
        } else {
          Navigator.pushReplacementNamed(context, HomeShellPage.routeName);
        }
      } else if (error != null) {
        // Show error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: const Color(0xFFE74C3C),
            action: error.contains('not active') 
              ? SnackBarAction(
                  label: 'RESEND OTP',
                  textColor: Colors.white,
                  onPressed: () async {
                    final success = await authProvider.resendOTP(
                      email: normalizedEmail,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(success 
                            ? 'OTP sent to your email' 
                            : 'Failed to resend OTP'
                          ),
                          backgroundColor: success ? Colors.green : Colors.red,
                        ),
                      );
                    }
                  },
                )
              : null,
          ),
        );
      }
    } else {
      // Sign Up
      final success = await authProvider.signUp(
        email: normalizedEmail,
        password: _passwordController.text,
        displayName: _displayNameController.text.trim().isEmpty 
          ? null 
          : _displayNameController.text.trim(),
      );
      
      if (!mounted) return;

      if (success) {
        // Navigate to OTP verification
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerifyOTPPage(email: normalizedEmail),
          ),
        );
      } else if (authProvider.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage!),
            backgroundColor: const Color(0xFFE74C3C),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECF0F1), // Clouds
      body: SafeArea(
        child: Column(
          children: [
            // Header with gradient
            _buildHeader(),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      _buildFormCard(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 300,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFE74C3C), // Alizarin
            Color(0xFFC0392B), // Pomegranate
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.1), width: 30),
              ),
            ),
          ),
          
          // Content
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Stack(
                    children: [
                      const Center(
                        child: Icon(
                          Icons.account_balance_wallet,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFC0392B), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'SplitPal',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Group Expense Manager',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Transform.translate(
      offset: const Offset(0, -96),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBDC3C7).withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tab Switcher
            _buildTabSwitcher(),
            const SizedBox(height: 24),
            
            // Form Fields
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Column(
                  children: [
                    if (!_isLoginMode) ...[
                      _buildTextField(
                        controller: _displayNameController,
                        label: 'Display Name (Optional)',
                        icon: Icons.person_outline,
                        hint: 'John Doe',
                      ),
                      const SizedBox(height: 20),
                    ],
                    
                    _buildTextField(
                      controller: _emailController,
                      label: 'Email Address',
                      icon: Icons.mail_outline,
                      hint: 'student@university.edu',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    
                    _buildTextField(
                      controller: _passwordController,
                      label: 'Password',
                      icon: Icons.lock_outline,
                      hint: '••••••••',
                      isPassword: true,
                    ),
                    const SizedBox(height: 16),
                    
                    if (_isLoginMode) _buildRememberMeRow(),
                    
                    const SizedBox(height: 32),
                    
                    // Submit Button
                    _buildSubmitButton(authProvider),

                    const SizedBox(height: 12),
                    _buildToggleAuthMode(),
                    
                    if (authProvider.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE74C3C).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          authProvider.errorMessage!,
                          style: const TextStyle(
                            color: Color(0xFFC0392B),
                            fontSize: 13,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 24),
                    
                    // Divider
                    Row(
                      children: [
                        Expanded(child: Container(height: 1, color: const Color(0xFFBDC3C7).withOpacity(0.5))),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Color(0xFFBDC3C7),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(child: Container(height: 1, color: const Color(0xFFBDC3C7).withOpacity(0.5))),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Google Sign In
                    _buildGoogleButton(),
                    
                    const SizedBox(height: 24),
                    
                    // Terms
                    _buildTermsText(),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleAuthMode() {
    return GestureDetector(
      onTap: () => setState(() => _isLoginMode = !_isLoginMode),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _isLoginMode ? "Don't have an account?" : 'Already have an account?',
            style: const TextStyle(fontSize: 13, color: Color(0xFF7F8C8D)),
          ),
          const SizedBox(width: 6),
          Text(
            _isLoginMode ? 'Create account' : 'Sign In',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFFE74C3C),
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFECF0F1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBDC3C7).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLoginMode = true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: _isLoginMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _isLoginMode
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)]
                      : null,
                ),
                child: Text(
                  'Sign In',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _isLoginMode ? const Color(0xFFE74C3C) : const Color(0xFF95A5A6),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _isLoginMode = false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: !_isLoginMode ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: !_isLoginMode
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2)]
                      : null,
                ),
                child: Text(
                  'Sign Up',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: !_isLoginMode ? const Color(0xFFE74C3C) : const Color(0xFF95A5A6),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    bool isPassword = false,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF7F8C8D),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        TextField(
          controller: controller,
          obscureText: isPassword && !_isPasswordVisible,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF95A5A6)),
            prefixIcon: Icon(icon, color: const Color(0xFFBDC3C7), size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                      color: const Color(0xFFBDC3C7),
                      size: 20,
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  )
                : null,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFBDC3C7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFBDC3C7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE74C3C)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildRememberMeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Checkbox(
              value: _rememberMe,
              onChanged: (value) => setState(() => _rememberMe = value ?? false),
              activeColor: const Color(0xFFE74C3C),
            ),
            const Text(
              'Remember me',
              style: TextStyle(fontSize: 12, color: Color(0xFF7F8C8D)),
            ),
          ],
        ),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ForgotPasswordPage(
                  initialEmail: _emailController.text,
                ),
              ),
            );
          },
          child: const Text(
            'Forgot password?',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFFE74C3C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(AuthProvider authProvider) {
    return ElevatedButton(
      onPressed: authProvider.isLoading ? null : _handleSubmit,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFFE74C3C),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 4,
      ),
      child: authProvider.isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isLoginMode ? 'Sign In' : 'Sign Up',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.login, size: 18),
              ],
            ),
    );
  }

  Widget _buildGoogleButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return OutlinedButton(
          onPressed: authProvider.isLoading ? null : () async {
            final error = await authProvider.loginWithGoogle();
            if (!mounted) return;
            
            if (error == null) {
              if (authProvider.shouldShowOnboarding()) {
                Navigator.pushReplacementNamed(context, OnboardingPage.routeName);
              } else {
                Navigator.pushReplacementNamed(context, HomeShellPage.routeName);
              }
            } else if (error != 'Đăng nhập Google bị hủy') {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(error),
                  backgroundColor: const Color(0xFFE74C3C),
                ),
              );
            }
          },
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 12),
            side: const BorderSide(color: Color(0xFFBDC3C7)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            'https://www.google.com/favicon.ico',
            width: 20,
            height: 20,
          ),
          const SizedBox(width: 10),
          const Text(
            'Sign in with Google',
            style: TextStyle(
              color: Color(0xFF333333),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildTermsText() {
    return const Text(
      'By signing in, you agree to our Terms and Privacy Policy.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 11,
        color: Color(0xFF95A5A6),
        height: 1.5,
      ),
    );
  }
}
