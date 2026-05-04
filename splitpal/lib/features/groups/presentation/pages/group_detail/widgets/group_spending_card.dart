
import 'package:flutter/material.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_card.dart';

class GroupSpendingCard extends StatefulWidget {
  final Map<String, dynamic> spending;
  final String currency;
  final void Function(int months)? onChangePeriod;

  const GroupSpendingCard({
    super.key,
    required this.spending,
    required this.currency,
    this.onChangePeriod,
  });

  @override
  State<GroupSpendingCard> createState() => _GroupSpendingCardState();
}

class _GroupSpendingCardState extends State<GroupSpendingCard> {
  static const _periodOptions = [3, 6, 12];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final s = widget.spending;

    final thisMonth = (s['thisMonth'] as num?)?.toDouble() ?? 0;
    final lastMonth = (s['lastMonth'] as num?)?.toDouble() ?? 0;
    final changePercent = (s['changePercent'] as num?)?.toDouble() ?? 0;
    final trend = s['trend'] as String? ?? 'STABLE';
    final totalAllTime = (s['totalAllTime'] as num?)?.toDouble() ?? 0;
    final months = (s['months'] as num?)?.toInt() ?? 6;
    final monthlyTrend = (s['monthlyTrend'] as List?) ?? [];
    final byMember = (s['byMember'] as List?) ?? [];

    final trendIcon = trend == 'UP'
        ? Icons.trending_up
        : trend == 'DOWN'
            ? Icons.trending_down
            : Icons.trending_flat;
    final trendColor = trend == 'UP'
        ? Colors.red.shade600
        : trend == 'DOWN'
            ? Colors.green.shade600
            : scheme.onSurfaceVariant;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Spending Analytics',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: trendColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(trendIcon, size: 14, color: trendColor),
                    const SizedBox(width: 3),
                    Text(
                      '${changePercent > 0 ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'All time: ${CurrencyFormatter.formatCurrency(totalAllTime, widget.currency)}',
            style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),

          // This month vs Last month
          Row(
            children: [
              Expanded(
                child: _ComparisonTile(
                  label: 'This month',
                  value: CurrencyFormatter.formatCurrency(thisMonth, widget.currency),
                  isHighlighted: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ComparisonTile(
                  label: 'Last month',
                  value: CurrencyFormatter.formatCurrency(lastMonth, widget.currency),
                  isHighlighted: false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Period selector
          Row(
            children: [
              Text(
                'Trend:',
                style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              ..._periodOptions.map((m) {
                final selected = m == months;
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: ChoiceChip(
                    label: Text('${m}m'),
                    selected: selected,
                    onSelected: (_) => widget.onChangePeriod?.call(m),
                    visualDensity: VisualDensity.compact,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),

          // Monthly bar chart
          if (monthlyTrend.isNotEmpty) _MonthlyBarChart(data: monthlyTrend),
          const SizedBox(height: 16),

          // Member breakdown
          if (byMember.isNotEmpty) ...[
            const Divider(height: 1),
            const SizedBox(height: 12),
            Text(
              'Top Spenders',
              style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...byMember.take(5).map((m) {
              final total = (m['total'] as num?)?.toDouble() ?? 0;
              final percent = (m['percent'] as num?)?.toInt() ?? 0;
              final name = m['displayName'] as String? ?? 'Unknown';
              final count = m['invoiceCount'] as int? ?? 0;
              return _MemberBar(
                name: name,
                amount: CurrencyFormatter.formatCurrency(total, widget.currency),
                percent: percent,
                invoiceCount: count,
              );
            }),
            if (byMember.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Center(
                  child: TextButton(
                    onPressed: () => _showAllMembers(context, byMember),
                    child: Text('View all ${byMember.length} members'),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _showAllMembers(BuildContext context, List members) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AllMembersSheet(
        members: members,
        currency: widget.currency,
      ),
    );
  }
}

class _ComparisonTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isHighlighted;

  const _ComparisonTile({
    required this.label,
    required this.value,
    required this.isHighlighted,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? scheme.primaryContainer.withOpacity(0.3)
            : scheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: isHighlighted ? scheme.primary : scheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List data;

  const _MonthlyBarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxVal = data.fold<double>(
        1, (a, m) => ((m['total'] as num?)?.toDouble() ?? 0) > a ? (m['total'] as num).toDouble() : a);

    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.map<Widget>((m) {
          final total = (m['total'] as num?)?.toDouble() ?? 0;
          final month = m['month'] as String? ?? '';
          final ratio = (total / maxVal).clamp(0.0, 1.0);
          final barH = total == 0 ? 4.0 : (6 + ratio * 50).clamp(4.0, 50.0);
          final label = month.length >= 7 ? month.substring(5) : month; // "01", "02"

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: barH,
                    decoration: BoxDecoration(
                      color: scheme.primary.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(fontSize: 8, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _MemberBar extends StatelessWidget {
  final String name;
  final String amount;
  final int percent;
  final int invoiceCount;

  const _MemberBar({
    required this.name,
    required this.amount,
    required this.percent,
    required this.invoiceCount,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$amount ($invoiceCount)',
                style: textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent / 100,
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AllMembersSheet extends StatelessWidget {
  final List members;
  final String currency;

  const _AllMembersSheet({required this.members, required this.currency});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'All Members Spending',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final m = members[index];
                final total = (m['total'] as num?)?.toDouble() ?? 0;
                final percent = (m['percent'] as num?)?.toInt() ?? 0;
                final name = m['displayName'] as String? ?? 'Unknown';
                final count = m['invoiceCount'] as int? ?? 0;
                return _MemberBar(
                  name: name,
                  amount: CurrencyFormatter.formatCurrency(total, currency),
                  percent: percent,
                  invoiceCount: count,
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
