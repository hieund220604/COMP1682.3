import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/features/auth/auth_provider.dart';

enum ForgotPasswordStep { email, otp, newPassword }

class ForgotPasswordPage extends StatefulWidget {
  final String? initialEmail;

  const ForgotPasswordPage({super.key, this.initialEmail});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  ForgotPasswordStep _currentStep = ForgotPasswordStep.email;
  
  // Email Step
  late final TextEditingController _emailController;
  
  // OTP Step
  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (index) => FocusNode());
  int _remainingSeconds = 59;
  Timer? _timer;
  
  // New Password Step
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  String? _resetToken;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (var c in _otpControllers) { c.dispose(); }
    for (var f in _otpFocusNodes) { f.dispose(); }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _remainingSeconds = 59);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _submitEmail() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      _showError('Please enter your email');
      return;
    }
    
    final authProvider = context.read<AuthProvider>();
    authProvider.clearError();
    final ok = await authProvider.forgotPassword(email: email);
    
    if (ok && mounted) {
      setState(() {
        _currentStep = ForgotPasswordStep.otp;
      });
      _startTimer();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _otpFocusNodes[0].requestFocus();
      });
    }
  }

  Future<void> _resendOTP() async {
    if (_remainingSeconds > 0) return;
    final email = _emailController.text.trim().toLowerCase();
    final authProvider = context.read<AuthProvider>();
    
    final ok = await authProvider.forgotPassword(email: email);
    if (!mounted) return;
    
    if (ok) {
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A new OTP has been sent to $email'), backgroundColor: Colors.green),
      );
    } else {
      _showError(authProvider.errorMessage ?? 'Failed to resend OTP');
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();
    if (otp.length != 6) {
      _showError('Please enter complete OTP');
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final authProvider = context.read<AuthProvider>();
    authProvider.clearError();
    
    final token = await authProvider.verifyResetOTP(email: email, otp: otp);
    if (token != null && mounted) {
      setState(() {
        _resetToken = token;
        _currentStep = ForgotPasswordStep.newPassword;
      });
    }
  }

  Future<void> _submitNewPassword() async {
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (newPass.isEmpty || confirmPass.isEmpty) {
      _showError('Please fill in both password fields');
      return;
    }
    if (newPass != confirmPass) {
      _showError('Passwords do not match');
      return;
    }
    if (_resetToken == null) {
      _showError('Invalid reset session, please try again from the start');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    authProvider.clearError();
    
    final ok = await authProvider.resetPasswordWithToken(
      resetToken: _resetToken!,
      newPassword: newPass,
    );

    if (ok && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Success'),
          content: const Text('Your password has been successfully reset. You can now login with your new password.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // close dialog
                Navigator.of(context).pop(); // return to login
              },
              child: const Text('Back to Login', style: TextStyle(color: Color(0xFFE74C3C), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFE74C3C),
      )
    );
  }

  void _onOtpChanged(String value, int index) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _otpFocusNodes[index + 1].requestFocus();
      } else {
        FocusScope.of(context).unfocus();
        _verifyOTP();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECF0F1), // Clouds background matching auth_page
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF333333)),
          onPressed: () {
            if (_currentStep == ForgotPasswordStep.email) {
              Navigator.pop(context);
            } else if (_currentStep == ForgotPasswordStep.otp) {
              setState(() => _currentStep = ForgotPasswordStep.email);
            } else {
              setState(() => _currentStep = ForgotPasswordStep.otp);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              
              Text(
                _currentStep == ForgotPasswordStep.email 
                  ? 'Forgot Password'
                  : _currentStep == ForgotPasswordStep.otp
                    ? 'Verify OTP'
                    : 'Reset Password',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              
              Text(
                _currentStep == ForgotPasswordStep.email 
                  ? 'Enter your registered email address to receive a password reset OTP.'
                  : _currentStep == ForgotPasswordStep.otp
                    ? "We've sent a 6-digit code to ${_emailController.text}. Please enter it below."
                    : 'Create a new secure password for your account.',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF7F8C8D),
                  height: 1.5,
                ),
              ),
              
              const SizedBox(height: 32),
              
              Container(
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
                padding: const EdgeInsets.all(24),
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    return Column(
                      children: [
                        if (_currentStep == ForgotPasswordStep.email) _buildEmailStep(),
                        if (_currentStep == ForgotPasswordStep.otp) _buildOtpStep(),
                        if (_currentStep == ForgotPasswordStep.newPassword) _buildNewPasswordStep(),
                        
                        if (authProvider.errorMessage != null && _currentStep != ForgotPasswordStep.otp) ...[
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
                        ] else if (authProvider.errorMessage != null && _currentStep == ForgotPasswordStep.otp) ...[
                          const SizedBox(height: 16),
                          Text(
                            authProvider.errorMessage!,
                            style: const TextStyle(color: Color(0xFFC0392B), fontSize: 13),
                          ),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: authProvider.isLoading
                                ? null
                                : _currentStep == ForgotPasswordStep.email
                                    ? _submitEmail
                                    : _currentStep == ForgotPasswordStep.otp
                                        ? _verifyOTP
                                        : _submitNewPassword,
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
                                : Text(
                                    _currentStep == ForgotPasswordStep.email
                                        ? 'Send OTP'
                                        : _currentStep == ForgotPasswordStep.otp
                                            ? 'Verify'
                                            : 'Reset Password',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'EMAIL ADDRESS',
            style: TextStyle(
              color: Color(0xFF7F8C8D),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: 'john@example.com',
            hintStyle: const TextStyle(color: Color(0xFF95A5A6)),
            prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFFBDC3C7), size: 20),
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

  Widget _buildOtpStep() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (index) {
            final hasFocus = _otpFocusNodes[index].hasFocus;
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: index < 5 ? 6 : 0),
                child: TextField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: _otpControllers[index].text.isNotEmpty || hasFocus
                        ? Colors.white
                        : const Color(0xFFF3F4F6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFBDC3C7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: _otpControllers[index].text.isNotEmpty
                            ? const Color(0xFFE74C3C)
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE74C3C), width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => _onOtpChanged(value, index),
                  onTap: () => setState(() {}),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 24),
        Text(
          _remainingSeconds > 0
              ? 'Resend code in 0:${_remainingSeconds.toString().padLeft(2, '0')}'
              : 'Code expired',
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFF9CA3AF),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        TextButton(
          onPressed: _remainingSeconds == 0 ? _resendOTP : null,
          child: Text(
            'Resend OTP',
            style: TextStyle(
              fontSize: 14,
              color: _remainingSeconds == 0
                  ? const Color(0xFFE74C3C)
                  : const Color(0xFF9CA3AF),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPasswordField(
          label: 'NEW PASSWORD',
          controller: _newPasswordController,
          isVisible: _isPasswordVisible,
          onVisibilityChanged: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          hint: '••••••••',
        ),
        const SizedBox(height: 20),
        _buildPasswordField(
          label: 'CONFIRM PASSWORD',
          controller: _confirmPasswordController,
          isVisible: _isConfirmPasswordVisible,
          onVisibilityChanged: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
          hint: '••••••••',
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label, 
    required TextEditingController controller, 
    required bool isVisible, 
    required VoidCallback onVisibilityChanged,
    required String hint
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            label,
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
          obscureText: !isVisible,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFF95A5A6)),
            prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFBDC3C7), size: 20),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: const Color(0xFFBDC3C7),
                size: 20,
              ),
              onPressed: onVisibilityChanged,
            ),
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
}
