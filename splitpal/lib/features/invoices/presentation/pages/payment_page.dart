import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/features/invoices/invoice_provider.dart';
import 'package:splitpal/features/auth/auth_provider.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import '../../../auth/presentation/widgets/totp_verification_dialog.dart';

class PaymentPage extends StatefulWidget {
  final String groupId;

  const PaymentPage({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  @override
  void initState() {
    super.initState();
    _loadTransfers();
  }

  Future<void> _loadTransfers() async {
    await context.read<InvoiceProvider>().loadMyTransfers(widget.groupId);
  }

  Future<void> _initiatePayment(String transferId) async {
    // Check if user has 2FA enabled
    final authProvider = context.read<AuthProvider>();
    final is2FAEnabled = authProvider.user?.twoFactorEnabled ?? false;
    String? totpToken;

    if (is2FAEnabled) {
      totpToken = await TotpVerificationDialog.show(context);
      if (totpToken == null || !mounted) return;
    }

    final provider = context.read<InvoiceProvider>();
    final result = await provider.initiatePayment(transferId, totpToken: totpToken);

    if (result != null) {
      if (mounted) {
        _showOTPDialog(transferId);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to initiate payment'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOTPDialog(String transferId) {
    final otpController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter OTP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please enter the OTP sent to your registered contact.'),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: 'OTP',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final provider = context.read<InvoiceProvider>();
              await provider.initiatePayment(transferId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('OTP resent')),
                );
              }
            },
            child: const Text('Resend OTP'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (otpController.text.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter OTP')),
                );
                return;
              }

              Navigator.pop(dialogContext);
              await _verifyAndPay(transferId, otpController.text);
            },
            child: const Text('Verify & Pay'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyAndPay(String transferId, String otp) async {
    final provider = context.read<InvoiceProvider>();
    final success = await provider.verifyOTPAndPay(transferId, otp);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadTransfers();
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Payment failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payments'),
      ),
      body: Consumer<InvoiceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadTransfers,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.transfers.isEmpty) {
            return const Center(
              child: Text('No payments to make'),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadTransfers,
            child: ListView.builder(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: provider.transfers.length,
              itemBuilder: (context, index) {
                final scheme = Theme.of(context).colorScheme;
                final textTheme = Theme.of(context).textTheme;
                final transfer = provider.transfers[index];
                
                return AppCard(
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: _getStatusColor(transfer.status, scheme),
                            child: Icon(
                              _getStatusIcon(transfer.status),
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Pay to ${transfer.toName}',
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  transfer.status,
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${transfer.amount.toStringAsFixed(2)}',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                      if (transfer.status == 'PENDING') ...[
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: () => _initiatePayment(transfer.id),
                            icon: const Icon(Icons.payment),
                            label: const Text('Pay Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                      if (transfer.status == 'COMPLETED') ...[
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color: Colors.green.shade600,
                              size: 16,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Completed on ${_formatDate(transfer.paidAt!)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Color _getStatusColor(String status, ColorScheme scheme) {
    switch (status) {
      case 'PENDING':
        return scheme.primary;
      case 'COMPLETED':
        return Colors.green.shade600;
      case 'CANCELLED':
        return scheme.error;
      default:
        return scheme.outlineVariant;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'PENDING':
        return Icons.pending;
      case 'COMPLETED':
        return Icons.check_circle;
      case 'CANCELLED':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
