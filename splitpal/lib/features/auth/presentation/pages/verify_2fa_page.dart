import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/features/auth/auth_provider.dart';

class Verify2FAPage extends StatefulWidget {
  const Verify2FAPage({super.key});

  @override
  State<Verify2FAPage> createState() => _Verify2FAPageState();
}

class _Verify2FAPageState extends State<Verify2FAPage> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  // Toggle between TOTP mode and backup code mode
  bool _isBackupCodeMode = false;

  static const _brand = AppColors.brand;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _switchMode(bool isBackupMode) {
    setState(() {
      _isBackupCodeMode = isBackupMode;
      _codeController.clear();
      _errorMessage = null;
    });
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter your verification code');
      return;
    }

    // Validate format
    if (!_isBackupCodeMode && code.length != 6) {
      setState(() => _errorMessage = 'TOTP code must be exactly 6 digits');
      return;
    }
    if (_isBackupCodeMode && code.length != 8) {
      setState(() => _errorMessage = 'Backup code must be exactly 8 characters');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    // Always normalize to lowercase — backup codes are stored as lowercase hex
    final error = await authProvider.verify2FALogin(token: code.toLowerCase());

    if (!mounted) return;

    // authProvider state is now either authenticated (success) or requires2FA (fail)
    if (error != null) {
      // If tempToken expired, the server returns an "expired" or "login again" message.
      // Since Verify2FAPage is the home widget (no back button), we must reset the
      // auth state to unauthenticated so Consumer rebuilds to AuthPage automatically.
      final isExpiredSession = error.toLowerCase().contains('expired') ||
          error.toLowerCase().contains('login again') ||
          error.toLowerCase().contains('invalid or expired');

      if (isExpiredSession) {
        context.read<AuthProvider>().forceLogout();
        // Consumer sees unauthenticated → rebuilds to AuthPage. No manual nav needed.
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
    // On success: Consumer sees AuthState.authenticated → rebuilds home.
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isDark
                      ? _brand.withOpacity(0.15)
                      : _brand.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
                child: Icon(
                  _isBackupCodeMode ? Icons.key : Icons.security,
                  size: 40,
                  color: _brand,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Two-Factor Authentication',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isBackupCodeMode
                    ? 'Enter one of your 8-character backup codes'
                    : 'Enter the 6-digit code from your\nauthenticator app',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.lg),
              // Mode toggle
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surfaceContainerHigh
                      : scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchMode(false),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isBackupCodeMode ? _brand : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadii.sm - 1),
                          ),
                          child: Text(
                            'Authenticator App',
                            textAlign: TextAlign.center,
                            style: textTheme.labelMedium?.copyWith(
                              color: !_isBackupCodeMode
                                  ? Colors.white
                                  : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _switchMode(true),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isBackupCodeMode ? _brand : Colors.transparent,
                            borderRadius: BorderRadius.circular(AppRadii.sm - 1),
                          ),
                          child: Text(
                            'Backup Code',
                            textAlign: TextAlign.center,
                            style: textTheme.labelMedium?.copyWith(
                              color: _isBackupCodeMode
                                  ? Colors.white
                                  : scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _codeController,
                // TOTP: numeric keyboard (digits only)
                // Backup code: text keyboard (hex: 0-9 + a-f)
                keyboardType: _isBackupCodeMode
                    ? TextInputType.visiblePassword
                    : TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: _isBackupCodeMode ? 8 : 6,
                autocorrect: false,
                enableSuggestions: false,
                inputFormatters: _isBackupCodeMode
                    ? [
                        // Allow hex characters only (a-f, A-F, 0-9)
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                        LengthLimitingTextInputFormatter(8),
                      ]
                    : [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: _isBackupCodeMode ? 4 : 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: _isBackupCodeMode ? 'a3f1b2c4' : '000000',
                  hintStyle: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurfaceVariant.withOpacity(0.2),
                    letterSpacing: _isBackupCodeMode ? 4 : 8,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.xl,
                  ),
                ),
                onSubmitted: (_) => _handleVerify(),
              ),
              if (_isBackupCodeMode) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Backup codes are 8-character codes (letters & numbers)',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _errorMessage!,
                  style: textTheme.bodySmall?.copyWith(color: scheme.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, _) {
                    final isDisabled = _isLoading || authProvider.isLoading;
                    return FilledButton(
                      onPressed: isDisabled ? null : _handleVerify,
                      child: isDisabled
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Verify',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
