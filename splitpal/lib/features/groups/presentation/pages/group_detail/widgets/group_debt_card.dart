import 'package:flutter/material.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/models/invoice.dart';
import 'package:splitpal/features/ai/presentation/widgets/debt_reminder_dialog.dart';

class GroupDebtCard extends StatelessWidget {
  final Map<String, dynamic> debts;
  final String currency;
  final String groupId;

  const GroupDebtCard({
    super.key,
    required this.debts,
    required this.currency,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final totalOutstanding = _sn(debts['totalOutstanding'])?.toDouble() ?? 0;
    final settledPercent = _sn(debts['settledPercent'])?.toInt() ?? 100;
    final items = (debts['items'] as List?) ?? [];

    if (totalOutstanding == 0 && items.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 10),
            Text(
              'All debts settled! 🎉',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.green.shade600,
              ),
            ),
          ],
        ),
      );
    }

    final progressColor = settledPercent >= 80
        ? Colors.green.shade600
        : settledPercent >= 50
            ? Colors.orange.shade600
            : Colors.red.shade600;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.balance_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Settlement Health',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress ring + stats
          Row(
            children: [
              // Circular progress
              SizedBox(
                width: 64,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: settledPercent / 100,
                      strokeWidth: 6,
                      backgroundColor: progressColor.withOpacity(0.15),
                      valueColor: AlwaysStoppedAnimation(progressColor),
                    ),
                    Text(
                      '$settledPercent%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: progressColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settled',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${CurrencyFormatter.formatCurrency(totalOutstanding, currency)} remaining',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: totalOutstanding > 0 ? Colors.red.shade600 : Colors.green.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (items.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Debt list
            ...items.take(5).map((item) {
              final debtorName = item['debtorName'] as String? ?? 'Unknown';
              final creditorName = item['creditorName'] as String? ?? 'Unknown';
              final amount = _sn(item['amount'])?.toDouble() ?? 0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    // Debtor avatar
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.red.shade50,
                      child: Text(
                        debtorName.isNotEmpty ? debtorName[0].toUpperCase() : '?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.red.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Names
                    Expanded(
                      child: RichText(
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        text: TextSpan(
                          style: textTheme.bodySmall,
                          children: [
                            TextSpan(
                              text: debtorName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: ' → ',
                              style: TextStyle(color: scheme.onSurfaceVariant),
                            ),
                            TextSpan(
                              text: creditorName,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Amount
                    Text(
                      CurrencyFormatter.formatCurrency(amount, currency),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    // AI Remind button
                    InkWell(
                      onTap: () {
                        final dummyTransfer = Transfer(
                          id: item['id']?.toString() ?? 'debt',
                          paymentRequestId: '',
                          groupId: groupId,
                          fromUserId: item['debtorId']?.toString() ?? '',
                          toUserId: item['creditorId']?.toString() ?? '',
                          amount: amount,
                          status: 'PENDING',
                          otpVerified: false,
                          createdAt: DateTime.now(),
                        );
                        DebtReminderDialog.show(
                          context,
                          debtorName: debtorName,
                          transfers: [dummyTransfer],
                          currency: currency,
                          groupId: groupId,
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.auto_awesome,
                          size: 16,
                          color: AppColors.brand,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (items.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Center(
                  child: Text(
                    '+${items.length - 5} more',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

num? _sn(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  if (v is Map) {
    final d = v['\$numberDecimal'] ?? v['numberDecimal'];
    if (d != null) return num.tryParse(d.toString());
  }
  return null;
}
