import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/features/auth/auth_provider.dart';

class Setup2FAPage extends StatefulWidget {
  const Setup2FAPage({super.key});

  @override
  State<Setup2FAPage> createState() => _Setup2FAPageState();
}

class _Setup2FAPageState extends State<Setup2FAPage> {
  int _step = 0; // 0 = loading, 1 = QR code, 2 = verify, 3 = backup codes
  String? _qrCodeUrl;
  String? _manualKey;
  List<String> _backupCodes = [];
  String? _errorMessage;
  bool _isLoading = false;
  final _codeController = TextEditingController();

  static const _brand = AppColors.brand;

  @override
  void initState() {
    super.initState();
    _initSetup();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initSetup() async {
    setState(() => _step = 0);
    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.setup2FA();

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _qrCodeUrl = result['qrCodeUrl'] as String?;
        _manualKey = result['manualKey'] as String?;
        _step = 1;
      });
    } else {
      setState(() {
        _errorMessage = 'Failed to initialize 2FA setup';
        _step = 1;
      });
    }
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.verifySetup2FA(token: code);

    if (!mounted) return;

    if (result != null && result['backupCodes'] != null) {
      final codes = (result['backupCodes'] as List).cast<String>();
      setState(() {
        _backupCodes = codes;
        _step = 3;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result?['error'] as String? ?? 'Invalid code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Up 2FA'),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return Center(
          child: CircularProgressIndicator(color: _brand),
        );
      case 1:
        return _buildQRCodeStep();
      case 2:
        return _buildVerifyStep();
      case 3:
        return _buildBackupCodesStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQRCodeStep() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          // Icon container
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? _brand.withOpacity(0.15)
                  : _brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              Icons.qr_code_2,
              size: 36,
              color: _brand,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Scan QR Code',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Scan this QR code with your authenticator app\n(Google Authenticator, Authy, etc.)',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // QR Code Image
          if (_qrCodeUrl != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(
                  color: scheme.outlineVariant.withOpacity(0.6),
                ),
              ),
              child: _buildQRImage(),
            ),
          if (_errorMessage != null && _qrCodeUrl == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: Text(
                _errorMessage!,
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          // Manual key
          if (_manualKey != null) ...[
            Text(
              'Or enter this key manually:',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _manualKey!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Key copied to clipboard')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? scheme.surfaceContainerHigh
                      : scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _manualKey!,
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(Icons.copy, size: 18, color: scheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => setState(() {
                _step = 2;
                _errorMessage = null;
              }),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildQRImage() {
    if (_qrCodeUrl == null) return const SizedBox.shrink();

    // QR code URL is a data URI (data:image/png;base64,...)
    if (_qrCodeUrl!.startsWith('data:image')) {
      final base64Str = _qrCodeUrl!.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        width: 220,
        height: 220,
        fit: BoxFit.contain,
      );
    }

    return Image.network(
      _qrCodeUrl!,
      width: 220,
      height: 220,
      fit: BoxFit.contain,
    );
  }

  Widget _buildVerifyStep() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? _brand.withOpacity(0.15)
                  : _brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              Icons.pin,
              size: 36,
              color: _brand,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Enter Verification Code',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter the 6-digit code shown in\nyour authenticator app',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              style: textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
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
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Verify & Enable',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextButton(
            onPressed: () => setState(() {
              _step = 1;
              _errorMessage = null;
              _codeController.clear();
            }),
            child: Text(
              'Back to QR Code',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCodesStep() {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        children: [
          const SizedBox(height: AppSpacing.xl),
          // Success icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.tertiary.withOpacity(0.15)
                  : scheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(
              Icons.check_circle,
              size: 36,
              color: scheme.tertiary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '2FA Enabled!',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Save these backup codes in a safe place.\nEach code can only be used once.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Backup codes container
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              color: isDark
                  ? _brand.withOpacity(0.06)
                  : AppColors.brandSurface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(
                color: _brand.withOpacity(isDark ? 0.2 : 0.15),
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: _brand),
                    const SizedBox(width: 6),
                    Text(
                      'Backup Codes',
                      style: textTheme.labelLarge?.copyWith(
                        color: _brand,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.md,
                  runSpacing: AppSpacing.sm,
                  children: _backupCodes.map((code) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? scheme.surfaceContainerHigh
                            : scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: Border.all(
                          color: scheme.outlineVariant.withOpacity(0.6),
                        ),
                      ),
                      child: Text(
                        code,
                        style: textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Copy all button
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _backupCodes.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup codes copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy All Codes'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xl,
                vertical: AppSpacing.md,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
