import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/savings/savings_provider.dart';

/// Confirmation dialog for withdrawing a deposit.
/// Shows principal, accrued interest, early-withdrawal warning, and total payout.
class WithdrawDialog extends StatefulWidget {
  final String depositId;
  final String goalId;
  final double principal;
  final double accruedInterest;
  final bool isEarlyWithdrawal;

  const WithdrawDialog({
    super.key,
    required this.depositId,
    required this.goalId,
    required this.principal,
    required this.accruedInterest,
    required this.isEarlyWithdrawal,
  });

  @override
  State<WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<WithdrawDialog> {
  bool _isProcessing = false;

  Future<void> _confirm() async {
    setState(() => _isProcessing = true);

    final provider = context.read<SavingsProvider>();
    final result = await provider.withdrawDeposit(
      depositId: widget.depositId,
      goalId: widget.goalId,
    );

    if (mounted) {
      Navigator.pop(context, true);
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Withdrawal completed')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Withdrawal failed')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final totalPayout = widget.principal + widget.accruedInterest;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
      title: Text(
        'Withdraw Deposit',
        style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.isEarlyWithdrawal)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              decoration: BoxDecoration(
                color: colorScheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: colorScheme.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Early withdrawal: interest will be recalculated at the flexible rate.',
                      style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),

          _InfoRow(label: 'Principal', value: CurrencyFormatter.formatVND(widget.principal)),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: 'Accrued Interest',
            value: '+${CurrencyFormatter.formatVND(widget.accruedInterest)}',
            valueColor: colorScheme.tertiary,
          ),
          const Divider(height: 24),
          _InfoRow(
            label: 'Total Payout',
            value: CurrencyFormatter.formatVND(totalPayout),
            isBold: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isProcessing ? null : _confirm,
          child: _isProcessing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirm'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  const _InfoRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: isBold
              ? textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
              : textTheme.bodySmall,
        ),
        Text(
          value,
          style: (isBold ? textTheme.titleMedium : textTheme.bodyMedium)?.copyWith(
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
