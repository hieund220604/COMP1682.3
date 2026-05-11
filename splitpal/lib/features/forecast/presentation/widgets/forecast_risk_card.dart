import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/forecast/forecast_provider.dart';
import 'package:splitpal/features/forecast/presentation/pages/cashflow_forecast_page.dart';

class ForecastRiskCard extends StatelessWidget {
  const ForecastRiskCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final provider = context.watch<ForecastProvider>();
    final summary = provider.summary;
    final isLoading = provider.isLoading;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CashflowForecastPage()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: isLoading && summary == null
            ? _buildLoading()
            : summary == null
                ? _buildEmpty()
                : _buildContent(context, summary, provider, scheme, textTheme),
      ),
    );
  }

  Widget _buildLoading() => const SizedBox(
        height: 72,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );

  Widget _buildEmpty() => const SizedBox(
        height: 72,
        child: Center(
          child: Text('Forecast unavailable',
              style: TextStyle(color: Colors.grey)),
        ),
      );

  Widget _buildContent(
    BuildContext context,
    ForecastSummary summary,
    ForecastProvider provider,
    ColorScheme scheme,
    TextTheme textTheme,
  ) {
    final isSafe = summary.isSafe;
    final highAlerts = summary.alerts.where((a) => a.isHigh).toList();
    final medAlerts = summary.alerts.where((a) => a.isMedium).toList();
    final days = summary.daysUntilNegative;

    final statusColor = isSafe
        ? Colors.green.shade600
        : (days != null && days <= 2
            ? Colors.red.shade700
            : Colors.orange.shade700);
    final statusIcon = isSafe
        ? Icons.shield_outlined
        : (days != null && days <= 2
            ? Icons.warning_rounded
            : Icons.info_outline);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──────────────────────────────────────────────────────────
        Row(
          children: [
            Icon(Icons.analytics_outlined, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              '7-Day Forecast',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            Icon(Icons.chevron_right,
                size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
        const SizedBox(height: 12),

        // ── Status banner ────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isSafe
                      ? 'Safe for the next ${summary.horizonDays} days'
                      : days != null
                          ? 'May go negative in $days day${days == 1 ? '' : 's'}'
                          : 'Balance risk detected',
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── Mini balance bar chart (uses daily data if loaded) ───────────────
        _MiniBarsChart(provider: provider, summary: summary),
        const SizedBox(height: 14),

        // ── Metrics row ──────────────────────────────────────────────────────
        Row(
          children: [
            _Metric(
              label: 'Outflow',
              value:
                  CurrencyFormatter.formatVNDCompact(summary.totalConfirmedOutflow),
              color: Colors.red.shade600,
            ),
            const SizedBox(width: 12),
            _Metric(
              label: 'Expected in',
              value:
                  CurrencyFormatter.formatVNDCompact(summary.totalExpectedInflow),
              color: Colors.green.shade600,
            ),
            const SizedBox(width: 12),
            _Metric(
              label: 'Min safe bal',
              value:
                  CurrencyFormatter.formatVNDCompact(summary.minimumSafeBalance),
              color: summary.minimumSafeBalance < 0
                  ? Colors.red.shade700
                  : Colors.blueGrey,
            ),
          ],
        ),

        // ── Alert list (compact, max 2) ───────────────────────────────────
        if (highAlerts.isNotEmpty || medAlerts.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),
          ...[...highAlerts, ...medAlerts].take(2).map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        a.isHigh ? Icons.error_outline : Icons.warning_amber,
                        size: 14,
                        color: a.isHigh ? Colors.red : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          a.message,
                          style: textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],

        const SizedBox(height: 10),

        // ── View Full button ─────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const CashflowForecastPage()),
            ),
            icon: const Icon(Icons.open_in_full, size: 15),
            label: const Text('View full forecast', style: TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
}

// ── Mini 7-bar chart ───────────────────────────────────────────────────────────

class _MiniBarsChart extends StatelessWidget {
  final ForecastProvider provider;
  final ForecastSummary summary;

  const _MiniBarsChart({required this.provider, required this.summary});

  @override
  Widget build(BuildContext context) {
    final daily = provider.dailyForecasts;

    // If no daily data fetched yet, show safe-days summary instead
    if (daily.isEmpty) {
      final days = summary.daysUntilNegative;
      final safeDays = days ?? summary.horizonDays;
      return _SafeDaysBar(safeDays: safeDays, total: summary.horizonDays);
    }

    final bars = daily.take(7).toList();
    if (bars.isEmpty) return const SizedBox();

    final maxVal = bars.map((d) => d.closingBalanceSafe).reduce(math.max);
    final minVal = bars.map((d) => d.closingBalanceSafe).reduce(math.min);
    final range = maxVal - minVal;

    // Create a baseline slightly below minVal to ensure the lowest bar still has visible height
    final baseline = range == 0 ? 0.0 : minVal - (range * 0.5); 
    final adjustedRange = range == 0 ? 1.0 : (maxVal - baseline);

    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: bars.map((day) {
          final val = day.closingBalanceSafe;
          
          double ratio;
          if (range == 0) {
            ratio = val > 0 ? 0.8 : 0.2; // Show flat height if no changes
          } else {
            ratio = ((val - baseline) / adjustedRange).clamp(0.0, 1.0);
          }

          // Max bar height = 36px so that bar(36) + gap(4) + label(12) + slack(20) = 72px
          final barH = (4 + ratio * 32).clamp(4.0, 36.0);
          final isNeg = day.isNegative;
          final date = DateTime.tryParse(day.date);
          
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: barH,
                    decoration: BoxDecoration(
                      color: isNeg
                          ? Colors.red.shade400
                          : Colors.green.shade500,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    date != null ? _dayLabel(date) : '',
                    style: const TextStyle(fontSize: 8, color: Colors.grey),
                    overflow: TextOverflow.clip,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return labels[(d.weekday - 1) % 7];
  }
}

class _SafeDaysBar extends StatelessWidget {
  final int safeDays;
  final int total;

  const _SafeDaysBar({required this.safeDays, required this.total});

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 1.0 : (safeDays / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$safeDays of $total days safe',
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor:
                  Colors.red.shade200.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(
                  pct > 0.7 ? Colors.green : Colors.orange),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Metric chip ────────────────────────────────────────────────────────────────

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Metric(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w800, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
