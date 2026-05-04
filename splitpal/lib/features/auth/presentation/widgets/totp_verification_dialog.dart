import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/core/theme/app_tokens.dart';

/// A reusable dialog that prompts the user for their 2FA TOTP code.
/// Returns the entered code as a [String], or `null` if cancelled.
///
/// Usage:
/// ```dart
/// final code = await TotpVerificationDialog.show(context);
/// if (code != null) { /* proceed with code */ }
/// ```
class TotpVerificationDialog extends StatefulWidget {
  const TotpVerificationDialog({super.key});

  /// Show the dialog and return the entered code, or null if cancelled.
  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const TotpVerificationDialog(),
    );
  }

  @override
  State<TotpVerificationDialog> createState() => _TotpVerificationDialogState();
}

class _TotpVerificationDialogState extends State<TotpVerificationDialog> {
  final _controller = TextEditingController();
  String? _error;

  static const _brand = AppColors.brand;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter your code');
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark
                  ? _brand.withOpacity(0.15)
                  : _brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.security, size: 20, color: _brand),
          ),
          const SizedBox(width: 10),
          Text(
            '2FA Verification',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter the 6-digit code from your authenticator app to continue.',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 8, // Allow backup codes
            autofocus: true,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]')),
            ],
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 6,
                color: scheme.onSurfaceVariant.withOpacity(0.2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.lg,
              ),
            ),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.error,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            'You can also use a backup code',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text(
            'Verify',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
