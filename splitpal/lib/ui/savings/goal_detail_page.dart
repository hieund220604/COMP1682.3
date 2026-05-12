import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/savings/savings_provider.dart';
import 'package:splitpal/ui/savings/create_deposit_sheet.dart';
import 'package:splitpal/ui/savings/withdraw_dialog.dart';

/// Detail page for a single Savings Goal.
/// Shows goal info, list of deposits, and action buttons.
class GoalDetailPage extends StatefulWidget {
  final String goalId;
  final String goalName;

  const GoalDetailPage({
    super.key,
    required this.goalId,
    required this.goalName,
  });

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavingsProvider>().fetchGoalDetail(widget.goalId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<SavingsProvider>();
    final goal = provider.currentGoal;

    return Scaffold(
      appBar: AppBar(title: Text(widget.goalName)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showModalBottomSheet<bool>(
            context: context,
            isScrollControlled: true,
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: CreateDepositSheet(goalId: widget.goalId),
            ),
          );
          if (result == true && mounted) {
            provider.fetchGoalDetail(widget.goalId);
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Deposit'),
      ),
      body: provider.isLoading && goal == null
          ? const Center(child: CircularProgressIndicator())
          : goal == null
              ? Center(
                  child: Text(
                    'Goal not found',
                    style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => provider.fetchGoalDetail(widget.goalId),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Progress Overview ──────────────────────
                        _GoalProgressCard(goal: goal),

                        const SizedBox(height: AppSpacing.xl),

                        // ── Deposits Section ───────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: Text(
                            'Deposits',
                            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),

                        _DepositsList(
                          goalId: widget.goalId,
                          deposits: List<Map<String, dynamic>>.from(goal['deposits'] ?? []),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

// ─── Progress Card ─────────────────────────────────────────────────────────────
class _GoalProgressCard extends StatelessWidget {
  final Map<String, dynamic> goal;

  const _GoalProgressCard({required this.goal});

  /// Calculate estimated time to reach target if user continues at the same pace.
  String? _buildProjection({
    required double currentAmount,
    required double targetAmount,
    required List<Map<String, dynamic>> deposits,
  }) {
    if (deposits.isEmpty || currentAmount >= targetAmount) return null;

    final active = deposits.where((d) => d['status'] != 'WITHDRAWN').toList();
    if (active.isEmpty) return null;

    double totalPrincipal = 0;
    double totalProjectedInterest = 0;
    double avgTermDays = 0;

    for (final d in active) {
      totalPrincipal += (d['amount'] as num?)?.toDouble() ?? 0;
      final projected = (d['projectedInterest'] as num?)?.toDouble();
      final accrued = (d['accruedInterest'] as num?)?.toDouble() ?? 0;
      totalProjectedInterest += projected ?? accrued;
      final term = (d['term'] as num?)?.toInt() ?? 0;
      avgTermDays += (term > 0 ? term : 30);
    }
    avgTermDays /= active.length;

    final valuePerCycle = totalPrincipal + totalProjectedInterest;
    if (valuePerCycle <= 0) return null;

    final remaining = targetAmount - currentAmount;
    final cyclesNeeded = remaining / valuePerCycle;
    final monthsNeeded = (cyclesNeeded * avgTermDays / 30).ceil();

    if (monthsNeeded <= 0) return null;
    if (monthsNeeded > 120) return 'Est. 10+ years to reach target';

    if (monthsNeeded >= 12) {
      final years = monthsNeeded ~/ 12;
      final months = monthsNeeded % 12;
      return months > 0
          ? 'Est. ~$years year${years > 1 ? 's' : ''} $months month${months > 1 ? 's' : ''} to reach target'
          : 'Est. ~$years year${years > 1 ? 's' : ''} to reach target';
    }
    return 'Est. ~$monthsNeeded month${monthsNeeded > 1 ? 's' : ''} to reach target';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final targetAmount = (goal['targetAmount'] as num?)?.toDouble() ?? 0;
    final currentAmount = (goal['currentAmount'] as num?)?.toDouble() ?? 0;
    final totalWithInterest = (goal['totalWithInterest'] as num?)?.toDouble() ?? currentAmount;
    final depositCount = (goal['depositCount'] as num?)?.toInt() ?? 0;
    final deposits = List<Map<String, dynamic>>.from(goal['deposits'] ?? []);
    final progress = targetAmount > 0 ? (totalWithInterest / targetAmount).clamp(0.0, 1.0) : 0.0;
    final icon = goal['icon'] as String? ?? '🎯';
    final status = goal['status'] as String? ?? 'ACTIVE';

    final projection = _buildProjection(
      currentAmount: totalWithInterest,
      targetAmount: targetAmount,
      deposits: deposits,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: AppSpacing.md),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal['name'] ?? '',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (status != 'ACTIVE')
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.onPrimary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: colorScheme.onPrimary.withOpacity(0.2),
                valueColor: AlwaysStoppedAnimation(colorScheme.onPrimary),
              ),
            ),

            const SizedBox(height: 14),

            // Main amount: current / target
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  CurrencyFormatter.formatVNDCompact(totalWithInterest),
                  style: textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    '/',
                    style: textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary.withOpacity(0.5),
                    ),
                  ),
                ),
                Text(
                  CurrencyFormatter.formatVNDCompact(targetAmount),
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Stats: %, deposits, interest
            Wrap(
              spacing: 12,
              children: [
                Text(
                  '${(progress * 100).toStringAsFixed(1)}% complete',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimary.withOpacity(0.85),
                  ),
                ),
                Text(
                  '\u00b7',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimary.withOpacity(0.5),
                  ),
                ),
                Text(
                  '$depositCount deposit${depositCount != 1 ? 's' : ''}',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimary.withOpacity(0.85),
                  ),
                ),
                if (totalWithInterest > currentAmount) ...[
                  Text(
                    '\u00b7',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimary.withOpacity(0.5),
                    ),
                  ),
                  Text(
                    '+${CurrencyFormatter.formatVNDCompact(totalWithInterest - currentAmount)} interest',
                    style: textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF4ADE80),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),

            // Projection banner
            if (projection != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timeline, size: 16, color: colorScheme.onPrimary.withOpacity(0.9)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        projection,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimary.withOpacity(0.9),
                          fontWeight: FontWeight.w600,
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
    );
  }
}

// ─── Deposits List ─────────────────────────────────────────────────────────────
class _DepositsList extends StatelessWidget {
  final String goalId;
  final List<Map<String, dynamic>> deposits;

  const _DepositsList({required this.goalId, required this.deposits});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (deposits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 40, color: colorScheme.onSurfaceVariant),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'No deposits yet',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Tap the Deposit button to add funds to this goal.',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      itemCount: deposits.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final deposit = deposits[index];
        return _DepositTile(goalId: goalId, deposit: deposit);
      },
    );
  }
}

// ─── Single Deposit Tile ───────────────────────────────────────────────────────
class _DepositTile extends StatelessWidget {
  final String goalId;
  final Map<String, dynamic> deposit;

  const _DepositTile({required this.goalId, required this.deposit});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final amount = (deposit['amount'] as num?)?.toDouble() ?? 0;
    final interest = (deposit['accruedInterest'] as num?)?.toDouble() ?? 0;
    final rate = (deposit['annualRate'] as num?)?.toDouble() ?? 0;
    final termLabel = deposit['termLabel'] as String? ?? '';
    final status = deposit['status'] as String? ?? 'HOLDING';
    final depositId = (deposit['id'] ?? deposit['_id'] ?? '').toString();

    final canWithdraw = status == 'HOLDING' || status == 'MATURED';

    Color statusColor;
    switch (status) {
      case 'MATURED':
        statusColor = colorScheme.tertiary;
        break;
      case 'WITHDRAWN':
        statusColor = colorScheme.onSurfaceVariant;
        break;
      default:
        statusColor = colorScheme.primary;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.15),
        ),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          // Left info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  CurrencyFormatter.formatVND(amount),
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '$termLabel · ${rate.toStringAsFixed(1)}%/yr',
                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.trending_up, size: 14, color: colorScheme.tertiary),
                    const SizedBox(width: 4),
                    Text(
                      '+${CurrencyFormatter.formatVND(interest)}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.tertiary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status + action
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  status,
                  style: textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (canWithdraw) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 30,
                  child: TextButton(
                    onPressed: () => _showWithdrawDialog(context, depositId, amount, interest, status),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: textTheme.labelSmall,
                    ),
                    child: const Text('Withdraw'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(
    BuildContext context,
    String depositId,
    double principal,
    double interest,
    String status,
  ) {
    showDialog(
      context: context,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SavingsProvider>(),
        child: WithdrawDialog(
          depositId: depositId,
          goalId: goalId,
          principal: principal,
          accruedInterest: interest,
          isEarlyWithdrawal: status == 'HOLDING',
        ),
      ),
    );
  }
}
