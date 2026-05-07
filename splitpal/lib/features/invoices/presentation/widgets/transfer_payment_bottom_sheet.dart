import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/constants/app_constants.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/auth/auth_provider.dart';
import 'package:splitpal/features/invoices/invoice_provider.dart';
import 'package:splitpal/features/receipts/receipt_provider.dart';
import 'package:splitpal/models/invoice.dart';
import 'package:splitpal/models/receipt.dart';
import 'package:splitpal/features/receipts/presentation/widgets/icon_helpers.dart';
import '../../../auth/presentation/widgets/totp_verification_dialog.dart';

Future<void> showTransferPaymentBottomSheet(
  BuildContext context, {
  required Transfer transfer,
  required String groupId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TransferPaymentSheet(
      transfer: transfer,
      groupId: groupId,
    ),
  );
}

class _TransferPaymentSheet extends StatefulWidget {
  final Transfer transfer;
  final String groupId;

  const _TransferPaymentSheet({
    required this.transfer,
    required this.groupId,
  });

  @override
  State<_TransferPaymentSheet> createState() => _TransferPaymentSheetState();
}

class _TransferPaymentSheetState extends State<_TransferPaymentSheet> {
  bool _isLoading = false;
  ReceiptTag? _selectedTag;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReceiptProvider>().loadTags();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final authProvider = context.watch<AuthProvider>();
    final currentBalance = authProvider.user?.balance ?? 0;
    final balanceAfterPayment = currentBalance - widget.transfer.amount;
    final isInsufficient = balanceAfterPayment < 0;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Header
            Text(
              'Complete Payment',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'To ${widget.transfer.toName}',
              style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Amount to pay
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadii.lg),
              ),
              child: Column(
                children: [
                  Text(
                    'Amount',
                    style: textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    CurrencyFormatter.formatVND(widget.transfer.amount),
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Balance Details
            _buildRow(
              'Current Balance',
              CurrencyFormatter.formatVND(currentBalance),
              textTheme,
              scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildRow(
              'After Payment',
              CurrencyFormatter.formatVND(balanceAfterPayment),
              textTheme,
              isInsufficient ? scheme.error : scheme.primary,
              isBold: true,
            ),

            if (isInsufficient) ...[
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: scheme.onErrorContainer, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Insufficient balance. Please top up your account.',
                        style: textTheme.bodySmall?.copyWith(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // Budget Selection
            Text(
              'Assign to Budget (Optional)',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Consumer<ReceiptProvider>(
              builder: (context, receiptProvider, child) {
                final tags = receiptProvider.tags;
                if (tags.isEmpty) {
                  return Text(
                    'No budget categories found.',
                    style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  );
                }
                return DropdownButtonFormField<ReceiptTag>(
                  value: _selectedTag,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: BorderSide(color: scheme.outline),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      borderSide: BorderSide(color: scheme.primary, width: 2),
                    ),
                  ),
                  hint: const Text('Select a category'),
                  items: tags.map((tag) {
                    return DropdownMenuItem(
                      value: tag,
                      child: Row(
                        children: [
                          if (tag.icon != null) ...[
                            Text(
                              materialIconToEmoji(tag.icon) ?? tag.icon!,
                              style: const TextStyle(fontSize: 18),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                          Text(tag.name),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedTag = val),
                );
              },
            ),

            const SizedBox(height: AppSpacing.xxl),

            // Submit Button
            FilledButton(
              onPressed: !isInsufficient && !_isLoading ? _initiatePayment : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                ),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : const Text('Proceed to Payment', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, TextTheme textTheme, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Future<void> _initiatePayment() async {
    final authProvider = context.read<AuthProvider>();
    final is2FAEnabled = authProvider.user?.twoFactorEnabled ?? false;
    String? totpToken;

    if (is2FAEnabled) {
      totpToken = await TotpVerificationDialog.show(context);
      if (totpToken == null || !mounted) return;
    }

    setState(() => _isLoading = true);

    final provider = context.read<InvoiceProvider>();
    final result = await provider.initiatePayment(widget.transfer.id, totpToken: totpToken);

    setState(() => _isLoading = false);

    if (result != null && mounted) {
      _showOTPDialog(result);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to initiate payment'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showOTPDialog(Map<String, dynamic> otpData) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => OTPVerificationDialog(
        transferId: widget.transfer.id,
        groupId: widget.groupId,
        categoryTagId: _selectedTag?.id,
        otpExpiresAt: otpData['otpExpiresAt'] != null
            ? DateTime.parse(otpData['otpExpiresAt'])
            : DateTime.now().add(const Duration(minutes: 5)),
      ),
    );
  }
}

class OTPVerificationDialog extends StatefulWidget {
  final String transferId;
  final String groupId;
  final DateTime otpExpiresAt;
  final String? categoryTagId;

  const OTPVerificationDialog({
    super.key,
    required this.transferId,
    required this.groupId,
    required this.otpExpiresAt,
    this.categoryTagId,
  });

  @override
  State<OTPVerificationDialog> createState() => _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends State<OTPVerificationDialog> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  int _remainingSeconds = 300;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
        _startCountdown();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;

    return AlertDialog(
      title: const Text('Enter OTP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'An OTP has been sent to your email. Please enter it below.',
            style: TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              hintText: '000000',
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Time remaining: ${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: TextStyle(
                  color: _remainingSeconds < 60 ? scheme.error : scheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              TextButton(
                onPressed: _remainingSeconds > 0 ? null : _resendOTP,
                child: const Text('Resend OTP'),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isVerifying || _otpController.text.length != 6
              ? null
              : _verifyOTP,
          child: _isVerifying
              ? SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.onPrimary,
                  ),
                )
              : const Text('Verify'),
        ),
      ],
    );
  }

  Future<void> _verifyOTP() async {
    setState(() => _isVerifying = true);

    final provider = context.read<InvoiceProvider>();
    final success = await provider.verifyOTPAndPay(
      widget.transferId,
      _otpController.text,
      categoryTagId: widget.categoryTagId,
    );

    setState(() => _isVerifying = false);

    if (success && mounted) {
      // Close OTP dialog
      Navigator.pop(context);
      // Close bottom sheet
      Navigator.pop(context);
      // Reload transfers
      provider.loadMyTransfers(widget.groupId);
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Payment successful!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Invalid OTP'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _resendOTP() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP resent to your email')),
    );
    setState(() => _remainingSeconds = 300);
  }
}
