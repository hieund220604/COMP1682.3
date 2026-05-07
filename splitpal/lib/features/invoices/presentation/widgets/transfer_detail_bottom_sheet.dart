import 'package:flutter/material.dart';

import 'package:splitpal/core/constants/app_constants.dart';
import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/models/invoice.dart';
import 'package:splitpal/features/invoices/presentation/widgets/transfer_payment_bottom_sheet.dart';
import 'package:intl/intl.dart';

/// Shows a detailed breakdown of which invoices/debts compose
/// a transfer's total amount, including any offsets from counter-debts.
class TransferDetailBottomSheet extends StatelessWidget {
  final Transfer transfer;
  final String groupId;
  final String currency;

  const TransferDetailBottomSheet({
    super.key,
    required this.transfer,
    required this.groupId,
    required this.currency,
  });

  /// Convenience method to show this bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required Transfer transfer,
    required String groupId,
    required String currency,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TransferDetailBottomSheet(
        transfer: transfer,
        groupId: groupId,
        currency: currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPending = transfer.status == 'PENDING';
    final isCompleted = transfer.status == 'COMPLETED';
    final isCancelled = transfer.status == 'CANCELLED';

    final statusColor = isCompleted
        ? scheme.tertiary
        : isCancelled
            ? scheme.onSurfaceVariant
            : Colors.orange;

    final statusLabel = isCompleted
        ? 'COMPLETED'
        : isCancelled
            ? 'CANCELLED'
            : 'PENDING';

    final ctx = transfer.debtContext;
    final hasContext = ctx != null && (ctx.youOwe.isNotEmpty || ctx.theyOwe.isNotEmpty);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadii.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ──
          const SizedBox(height: AppSpacing.md),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // ── Header ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Column(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Icon(
                    isCompleted
                        ? AppIcons.checkCircle
                        : AppIcons.payments,
                    color: statusColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Amount
                Text(
                  CurrencyFormatter.formatCurrency(transfer.amount, currency),
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),

                // To user
                Text(
                  'To ${transfer.toName.isNotEmpty ? transfer.toName : "User"}',
                  style: textTheme.bodyLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    statusLabel,
                    style: textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

                // Date info
                const SizedBox(height: AppSpacing.sm),
                Text(
                  isCompleted && transfer.paidAt != null
                      ? 'Paid on ${DateFormat(AppConstants.displayDateTimeFormat).format(transfer.paidAt!)}'
                      : 'Created ${DateFormat(AppConstants.displayDateTimeFormat).format(transfer.createdAt)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Debt breakdown content ──
          Flexible(
            child: hasContext
                ? _buildDebtContextView(context, ctx!)
                : _buildFallbackView(context),
          ),

          // ── Pay button (only for PENDING) ──
          if (isPending) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close bottom sheet
                    showTransferPaymentBottomSheet(
                      context,
                      transfer: transfer,
                      groupId: groupId,
                    );
                  },
                  icon: const Icon(AppIcons.payments),
                  label: const Text('Proceed to Pay'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md + 2,
                    ),
                    textStyle: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  /// Main view using debtContext — shows youOwe, theyOwe, and net calculation.
  Widget _buildDebtContextView(BuildContext context, DebtContext ctx) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── "You Owe" section ──
          _buildSectionHeader(
            context,
            icon: Icons.arrow_upward_rounded,
            label: 'You Owe',
            color: scheme.error,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...ctx.youOwe.map((e) => _buildDebtRow(
                context,
                title: e.invoiceTitle,
                amount: e.debtAmount,
                color: scheme.error,
              )),

          // ── "They Owe You" section (offset) ──
          if (ctx.hasOffset) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildSectionHeader(
              context,
              icon: Icons.arrow_downward_rounded,
              label: 'They Owe You',
              color: scheme.tertiary,
            ),
            const SizedBox(height: AppSpacing.sm),
            ...ctx.theyOwe.map((e) => _buildDebtRow(
                  context,
                  title: e.invoiceTitle,
                  amount: e.debtAmount,
                  color: scheme.tertiary,
                  isOffset: true,
                )),
          ],

          // ── Summary ──
          const SizedBox(height: AppSpacing.lg),
          Divider(color: scheme.outlineVariant.withOpacity(0.5)),
          const SizedBox(height: AppSpacing.md),

          // Subtotals
          if (ctx.hasOffset) ...[
            _buildSummaryRow(
              context,
              label: 'Total you owe',
              amount: ctx.totalYouOwe,
              color: scheme.error,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildSummaryRow(
              context,
              label: 'Offset (they owe you)',
              amount: -ctx.totalTheyOwe,
              color: scheme.tertiary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(color: scheme.outlineVariant.withOpacity(0.3)),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Net transfer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Net Transfer',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                CurrencyFormatter.formatCurrency(transfer.amount, currency),
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  /// Fallback view when debtContext is not available.
  Widget _buildFallbackView(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (transfer.debtAllocations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.info,
              size: 36,
              color: scheme.onSurfaceVariant.withOpacity(0.4),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No detailed breakdown available',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    // Fallback: show allocations only
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            context,
            icon: Icons.arrow_upward_rounded,
            label: 'From Invoices',
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.sm),
          ...transfer.debtAllocations.map((a) => _buildDebtRow(
                context,
                title: a.invoiceTitle,
                amount: a.allocatedAmount,
                color: Theme.of(context).colorScheme.onSurface,
              )),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  // ── Shared widgets ──

  Widget _buildSectionHeader(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Divider(color: scheme.outlineVariant.withOpacity(0.5)),
        ),
      ],
    );
  }

  Widget _buildDebtRow(
    BuildContext context, {
    required String title,
    required double amount,
    required Color color,
    bool isOffset = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Icon(
                AppIcons.invoices,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              '${isOffset ? '- ' : ''}${CurrencyFormatter.formatCurrency(amount, currency)}',
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final isNegative = amount < 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          '${isNegative ? '- ' : ''}${CurrencyFormatter.formatCurrency(amount.abs(), currency)}',
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }
}
