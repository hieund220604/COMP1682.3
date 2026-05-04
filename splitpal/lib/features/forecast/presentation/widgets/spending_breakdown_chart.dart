
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/forecast/forecast_models.dart';

class SpendingBreakdownChart extends StatefulWidget {
  final SpendingInsight insight;
  final VoidCallback? onChangePeriod;

  const SpendingBreakdownChart({
    super.key,
    required this.insight,
    this.onChangePeriod,
  });

  @override
  State<SpendingBreakdownChart> createState() => _SpendingBreakdownChartState();
}

class _SpendingBreakdownChartState extends State<SpendingBreakdownChart> {
  int _touchedIndex = -1;

  static const _chartColors = [
    Color(0xFFE8472A), // brand red
    Color(0xFF3182CE), // blue
    Color(0xFF38A169), // green
    Color(0xFFDD6B20), // orange
    Color(0xFF805AD5), // purple
    Color(0xFFD53F8C), // pink
    Color(0xFF319795), // teal
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final insight = widget.insight;
    final categories = insight.categoryBreakdown;

    // Trend display
    final trendIcon = insight.isUp
        ? Icons.trending_up
        : insight.isDown
            ? Icons.trending_down
            : Icons.trending_flat;
    final trendColor = insight.isUp
        ? Colors.red.shade600
        : insight.isDown
            ? Colors.green.shade600
            : scheme.onSurfaceVariant;
    final trendText = insight.isUp
        ? '+${insight.changePercent.toStringAsFixed(1)}%'
        : insight.isDown
            ? '${insight.changePercent.toStringAsFixed(1)}%'
            : 'Stable';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.pie_chart_outline, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Spending Breakdown',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              // Trend badge
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
                      trendText,
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
          const SizedBox(height: 6),
          // Period + total
          Text(
            'Last ${insight.periodDays} days · ${CurrencyFormatter.formatVNDCompact(insight.currentPeriodOutflow)} đ total',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),

          if (categories.isEmpty)
            SizedBox(
              height: 120,
              child: Center(
                child: Text(
                  'No spending data yet',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else ...[
            // Pie chart + center label
            SizedBox(
              height: 160,
              child: Row(
                children: [
                  // Pie chart
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  response == null ||
                                  response.touchedSection == null) {
                                _touchedIndex = -1;
                                return;
                              }
                              _touchedIndex = response
                                  .touchedSection!.touchedSectionIndex;
                            });
                          },
                        ),
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        sections: categories.asMap().entries.map((entry) {
                          final i = entry.key;
                          final cat = entry.value;
                          final isTouched = i == _touchedIndex;
                          final color =
                              _chartColors[i % _chartColors.length];
                          return PieChartSectionData(
                            value: cat.amount,
                            title: '${cat.percent}%',
                            titleStyle: TextStyle(
                              fontSize: isTouched ? 12 : 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            color: color,
                            radius: isTouched ? 42 : 34,
                            titlePositionPercentageOffset: 0.55,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Legend
                  Expanded(
                    flex: 4,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: categories
                          .take(5)
                          .toList()
                          .asMap()
                          .entries
                          .map((entry) {
                        final i = entry.key;
                        final cat = entry.value;
                        final color = _chartColors[i % _chartColors.length];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  cat.label,
                                  style: textTheme.bodySmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                '${cat.percent}%',
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Quick stats row
            Row(
              children: [
                _QuickStat(
                  label: 'Daily avg',
                  value: CurrencyFormatter.formatVNDCompact(
                      insight.dailyAvgSpending),
                ),
                if (insight.peakSpendingDay != null)
                  _QuickStat(
                    label: 'Peak day',
                    value: insight.peakSpendingDay!,
                  ),
                if (insight.subscriptionPercent > 0)
                  _QuickStat(
                    label: 'Subscriptions',
                    value: '${insight.subscriptionPercent}%',
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String label;
  final String value;

  const _QuickStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
