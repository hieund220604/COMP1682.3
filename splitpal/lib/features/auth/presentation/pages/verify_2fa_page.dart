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

  static const _brand = AppColors.brand;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorMessage = 'Please enter your verification code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    // Convert to lowercase to support backup codes without case sensitivity issues
    final error = await authProvider.verify2FALogin(token: code.toLowerCase());

    if (!mounted) return;

    if (error == null) {
      // Clear the navigator stack to reveal the HomeShellPage or OnboardingPage 
      // set by main.dart's Consumer
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = error;
      });
    }
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
        child: Padding(
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
                child: Icon(Icons.security, size: 40, color: _brand),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Two-Factor Authentication',
                style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Enter the 6-digit code from your\nauthenticator app',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 8,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
                ],
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '000000',
                  hintStyle: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurfaceVariant.withOpacity(0.2),
                    letterSpacing: 8,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.xl,
                  ),
                ),
                onSubmitted: (_) => _handleVerify(),
              ),
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
                child: FilledButton(
                  onPressed: _isLoading ? null : _handleVerify,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24, height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'You can also use a backup code',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
