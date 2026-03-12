import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/invoice.dart';
import '../providers/invoice_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/widgets/totp_verification_dialog.dart';

class TransferPaymentPage extends StatefulWidget {
  final Transfer transfer;
  final String groupId;

  const TransferPaymentPage({
    super.key,
    required this.transfer,
    required this.groupId,
  });

  @override
  State<TransferPaymentPage> createState() => _TransferPaymentPageState();
}

class _TransferPaymentPageState extends State<TransferPaymentPage> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final currentBalance = authProvider.user?.balance ?? 0;
    final balanceAfterPayment = currentBalance - widget.transfer.amount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Transfer'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.payment,
                    size: 64,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Payment Amount',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.formatVND(widget.transfer.amount),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'To ${widget.transfer.toName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Balance Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Balance Information',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.midnightBlue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildBalanceRow(
                    'Current Balance',
                    currentBalance,
                    Colors.blue,
                  ),
                  const SizedBox(height: 12),
                  _buildBalanceRow(
                    'Payment Amount',
                    -widget.transfer.amount,
                    Colors.red,
                  ),
                  const Divider(height: 32),
                  _buildBalanceRow(
                    'Balance After Payment',
                    balanceAfterPayment,
                    balanceAfterPayment >= 0 ? Colors.green : Colors.red,
                    isBold: true,
                  ),
                  
                  if (balanceAfterPayment < 0) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Insufficient balance. Please top up your account first.',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: balanceAfterPayment >= 0 && !_isLoading
                ? _initiatePayment
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              disabledBackgroundColor: Colors.grey.shade300,
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Proceed to Payment',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildBalanceRow(String label, double amount, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: AppColors.midnightBlue,
          ),
        ),
        Text(
          CurrencyFormatter.formatVND(amount.abs()),
          style: TextStyle(
            fontSize: isBold ? 18 : 16,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _initiatePayment() async {
    // Check if user has 2FA enabled
    final authProvider = context.read<AuthProvider>();
    final is2FAEnabled = authProvider.user?.twoFactorEnabled ?? false;
    String? totpToken;

    if (is2FAEnabled) {
      totpToken = await TotpVerificationDialog.show(context);
      if (totpToken == null || !mounted) return; // User cancelled
    }

    setState(() => _isLoading = true);

    final provider = context.read<InvoiceProvider>();
    final result = await provider.initiatePayment(widget.transfer.id, totpToken: totpToken);

    setState(() => _isLoading = false);

    if (result != null && mounted) {
      // Show OTP dialog
      _showOTPDialog(result);
    } else if (mounted) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to initiate payment'),
          backgroundColor: Colors.red,
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

  const OTPVerificationDialog({
    super.key,
    required this.transferId,
    required this.groupId,
    required this.otpExpiresAt,
  });

  @override
  State<OTPVerificationDialog> createState() => _OTPVerificationDialogState();
}

class _OTPVerificationDialogState extends State<OTPVerificationDialog> {
  final _otpController = TextEditingController();
  bool _isVerifying = false;
  int _remainingSeconds = 300; // 5 minutes

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
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
                  color: _remainingSeconds < 60 ? Colors.red : Colors.grey,
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
        ElevatedButton(
          onPressed: _isVerifying || _otpController.text.length != 6
              ? null
              : _verifyOTP,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: _isVerifying
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    );

    setState(() => _isVerifying = false);

    if (success && mounted) {
      // Close dialog
      Navigator.pop(context);
      // Close payment page
      Navigator.pop(context);
      // Reload transfers
      provider.loadMyTransfers(widget.groupId);
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment successful!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Invalid OTP'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _resendOTP() async {
    // TODO: Implement resend OTP
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP resent to your email')),
    );
    setState(() => _remainingSeconds = 300);
  }
}
