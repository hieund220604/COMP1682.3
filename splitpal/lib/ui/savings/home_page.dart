import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/features/savings/savings_provider.dart';
import 'package:splitpal/ui/savings/create_goal_sheet.dart';
import 'package:splitpal/ui/savings/goal_detail_page.dart';

/// Home page for the Savings feature.
/// Uses SavingsProvider for live data from the API.
class SavingsHomePage extends StatefulWidget {
  const SavingsHomePage({super.key});

  @override
  State<SavingsHomePage> createState() => _SavingsHomePageState();
}

class _SavingsHomePageState extends State<SavingsHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavingsProvider>().fetchGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<SavingsProvider>();
    final goals = provider.goals;
    final summary = provider.summary;

    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await showModalBottomSheet<Map<String, dynamic>>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const CreateGoalSheet(),
          );
          if (result != null && mounted) {
            final success = await provider.createGoal(
              name: result['name'] as String,
              targetAmount: result['targetAmount'] as double,
              icon: result['icon'] as String?,
              deadline: result['deadline'] as String?,
            );
            if (success && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Goal created')),
              );
            }
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('New Goal'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => provider.fetchGoals(),
          child: provider.isLoading && goals.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: AppSpacing.md),

                      // ── Summary Card ─────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: _SummaryCard(summary: summary),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // ── Section Header ───────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                        child: Text(
                          'Your Goals',
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),

                      const SizedBox(height: AppSpacing.md),

                      // ── Goal List ────────────────────────────────
                      if (goals.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Center(
                            child: Column(
                              children: [
                                Icon(Icons.savings_outlined, size: 48, color: colorScheme.onSurfaceVariant),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'No savings goals yet',
                                  style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Tap the button below to create your first goal.',
                                  style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          itemCount: goals.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) => _GoalCard(goal: goals[index]),
                        ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Summary Card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final Map<String, dynamic> summary;

  const _SummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final totalBalance = (summary['totalBalance'] as num?)?.toDouble() ?? 0;
    final totalSavings = (summary['totalSavings'] as num?)?.toDouble() ?? 0;
    final totalInterest = (summary['totalInterest'] as num?)?.toDouble() ?? 0;
    final activeGoals = (summary['activeGoals'] as num?)?.toInt() ?? 0;

    return Container(
      width: double.infinity,
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
              Icon(Icons.savings, color: colorScheme.onPrimary.withOpacity(0.8), size: 20),
              const SizedBox(width: 8),
              Text(
                'Total Savings',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onPrimary.withOpacity(0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyFormatter.formatVND(totalBalance),
            style: textTheme.displaySmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _MiniStat(
                label: 'Principal',
                value: CurrencyFormatter.formatVNDCompact(totalSavings),
                colorScheme: colorScheme,
                textTheme: textTheme,
              ),
              const SizedBox(width: 24),
              _MiniStat(
                label: 'Interest',
                value: '+${CurrencyFormatter.formatVNDCompact(totalInterest)}',
                colorScheme: colorScheme,
                textTheme: textTheme,
                valueColor: const Color(0xFF4ADE80),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$activeGoals active goal${activeGoals != 1 ? 's' : ''}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onPrimary.withOpacity(0.85),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final Color? valueColor;

  const _MiniStat({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: textTheme.labelSmall?.copyWith(color: colorScheme.onPrimary.withOpacity(0.7))),
        Text(value, style: textTheme.bodyMedium?.copyWith(color: valueColor ?? colorScheme.onPrimary, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ─── Goal Card ─────────────────────────────────────────────────────────────────
class _GoalCard extends StatelessWidget {
  final Map<String, dynamic> goal;

  const _GoalCard({required this.goal});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final id = (goal['id'] ?? goal['_id'] ?? '').toString();
    final name = goal['name'] as String? ?? '';
    final targetAmount = (goal['targetAmount'] as num?)?.toDouble() ?? 0;
    final currentAmount = (goal['currentAmount'] as num?)?.toDouble() ?? 0;
    final icon = goal['icon'] as String? ?? '🎯';
    final depositCount = (goal['depositCount'] as num?)?.toInt() ?? 0;
    final status = goal['status'] as String? ?? 'ACTIVE';

    final progress = targetAmount > 0
        ? (currentAmount / targetAmount).clamp(0.0, 1.0)
        : 0.0;
    final progressPct = (progress * 100).toStringAsFixed(0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GoalDetailPage(goalId: id, goalName: name),
          ),
        );
      },
      child: Container(
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
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  alignment: Alignment.center,
                  child: Text(icon, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (status == 'COMPLETED')
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(Icons.check_circle, size: 16, color: colorScheme.tertiary),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${CurrencyFormatter.formatVND(currentAmount)} / ${CurrencyFormatter.formatVND(targetAmount)}',
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      if (depositCount > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          '$depositCount deposit${depositCount != 1 ? 's' : ''}',
                          style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  '$progressPct%',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: progress >= 1.0 ? colorScheme.tertiary : colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 14, color: colorScheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: colorScheme.surfaceContainerHigh,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0 ? colorScheme.tertiary : colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
