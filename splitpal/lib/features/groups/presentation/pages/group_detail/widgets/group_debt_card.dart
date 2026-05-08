import 'package:flutter/material.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/models/invoice.dart';
import 'package:splitpal/features/ai/presentation/widgets/debt_reminder_dialog.dart';

class GroupDebtCard extends StatefulWidget {
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
  State<GroupDebtCard> createState() => _GroupDebtCardState();
}

class _GroupDebtCardState extends State<GroupDebtCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final totalOutstanding = _sn(widget.debts['totalOutstanding'])?.toDouble() ?? 0;
    final settledPercent = _sn(widget.debts['settledPercent'])?.toInt() ?? 100;
    final items = (widget.debts['items'] as List?) ?? [];

    if (totalOutstanding == 0 && items.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade600, size: 20),
            const SizedBox(width: 10),
            Text(
              'No pending transfers',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.green.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Group Pending Transfers',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${items.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Total pending: ${CurrencyFormatter.formatCurrency(totalOutstanding, widget.currency)}',
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),

          if (items.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            // Debt list
            ...items.take(_isExpanded ? items.length : 5).map((item) {
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
                      CurrencyFormatter.formatCurrency(amount, widget.currency),
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
                          groupId: widget.groupId,
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
                          currency: widget.currency,
                          groupId: widget.groupId,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.brand.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 14,
                              color: AppColors.brand,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Nhắc',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: AppColors.brand,
                              ),
                            ),
                          ],
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
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _isExpanded = !_isExpanded;
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        _isExpanded ? 'Show less' : '+${items.length - 5} more',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
