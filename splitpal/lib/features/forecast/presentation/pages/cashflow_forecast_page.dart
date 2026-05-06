import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/forecast/forecast_provider.dart';
import 'package:splitpal/features/forecast/presentation/widgets/event_detail_sheet.dart';
import 'package:splitpal/features/forecast/presentation/widgets/smart_tips_section.dart';
import 'package:splitpal/features/forecast/presentation/widgets/spending_breakdown_chart.dart';

class CashflowForecastPage extends StatefulWidget {
  const CashflowForecastPage({super.key});

  static const routeName = '/forecast';

  @override
  State<CashflowForecastPage> createState() => _CashflowForecastPageState();
}

class _CashflowForecastPageState extends State<CashflowForecastPage> {
  final _scrollController = ScrollController();
  final Map<String, GlobalKey> _dayKeys = {};
  int? _highlightedDayIndex;

  static const _horizonOptions = [7, 14, 30];
  static const _spendingPeriodOptions = [7, 14, 30, 60];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ForecastProvider>().fetchFull(days: 7);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToDay(int index) {
    final key = _dayKeys['day_$index'];
    if (key?.currentContext == null) return;
    Scrollable.ensureVisible(
      key!.currentContext!,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      alignment: 0.1,
    );
    setState(() => _highlightedDayIndex = index);
    Future.delayed(const Duration(seconds: 2),
        () => setState(() => _highlightedDayIndex = null));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.watch<ForecastProvider>();
    final summary = provider.summary;
    final days = provider.dailyForecasts;
    final isLoading = provider.isFullLoading;
    final horizon = provider.horizonDays;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // ── AppBar ────────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: scheme.surface,
            title: const Text(
              'Cashflow Forecast',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(height: 1, color: scheme.outlineVariant),
            ),
          ),

          // ── Header metrics ────────────────────────────────────────────────
          if (summary != null)
            SliverToBoxAdapter(
              child: _HeaderMetrics(summary: summary, showHealthScore: true),
            ),

          // ── Horizon selector ──────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: _horizonOptions.map((d) {
                  final selected = d == horizon;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('${d}d'),
                      selected: selected,
                      onSelected: (_) =>
                          context.read<ForecastProvider>().setHorizon(d),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // ── Balance Chart ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: isLoading && days.isEmpty
                  ? const _ChartSkeleton()
                  : days.isEmpty
                      ? const SizedBox.shrink()
                      : _BalanceChart(
                          days: days,
                          onTapDay: _scrollToDay,
                        ),
            ),
          ),

          // ── Smart Tips ─────────────────────────────────────────────────────
          if (provider.smartTips.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SmartTipsSection(tips: provider.smartTips),
              ),
            ),

          // ── Spending Period Selector ────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Spending analysis:',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ..._spendingPeriodOptions.map((d) {
                    final selected = d == provider.spendingDays;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${d}d'),
                        selected: selected,
                        onSelected: (_) =>
                            context.read<ForecastProvider>().setSpendingDays(d),
                        visualDensity: VisualDensity.compact,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // ── Spending Breakdown ─────────────────────────────────────────────
          if (provider.spendingInsight != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SpendingBreakdownChart(
                  insight: provider.spendingInsight!,
                ),
              ),
            ),

          // ── Event list ────────────────────────────────────────────────────
          if (isLoading && days.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (days.every((d) => !d.hasEvents))
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_outline,
                          size: 56, color: Colors.green),
                      SizedBox(height: 16),
                      Text(
                        'No upcoming payments',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Your balance looks clear for this period.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverList.builder(
              itemCount: days.where((d) => d.hasEvents).length,
              itemBuilder: (context, index) {
                final dayEvents =
                    days.where((d) => d.hasEvents).toList();
                final day = dayEvents[index];
                final originalIndex = days.indexOf(day);
                final key =
                    _dayKeys.putIfAbsent('day_$originalIndex', GlobalKey.new);
                return KeyedSubtree(
                  key: key,
                  child: _DayGroup(
                    day: day,
                    isHighlighted: _highlightedDayIndex == originalIndex,
                  ),
                );
              },
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }
}

// ── Header Metrics ─────────────────────────────────────────────────────────────

class _HeaderMetrics extends StatelessWidget {
  final ForecastSummary summary;
  final bool showHealthScore;
  const _HeaderMetrics({required this.summary, this.showHealthScore = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isSafe = summary.isSafe;
    final days = summary.daysUntilNegative;

    final statusColor = isSafe
        ? Colors.green.shade600
        : (days != null && days <= 2
            ? Colors.red.shade700
            : Colors.orange.shade700);
    final statusMsg = isSafe
        ? 'Balance is safe for the next ${summary.horizonDays} days'
        : 'Balance may go negative in ${days ?? '?'} day${days == 1 ? '' : 's'}';

    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSafe ? Icons.shield_outlined : Icons.warning_rounded,
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          statusMsg,
                          style: TextStyle(
                              color: statusColor, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (showHealthScore) ...[
                const SizedBox(width: 12),
                _HealthScoreBadge(
                  score: summary.healthScore,
                  label: summary.healthLabel,
                  color: summary.healthColor,
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MetricTile(
                label: 'Current balance',
                value: CurrencyFormatter.formatVNDCompact(
                    summary.currentBalance),
                color: scheme.primary,
              ),
              _MetricTile(
                label: 'Min safe balance',
                value: CurrencyFormatter.formatVNDCompact(
                    summary.minimumSafeBalance),
                color: summary.minimumSafeBalance < 0
                    ? Colors.red
                    : Colors.blueGrey,
              ),
              _MetricTile(
                label: 'Total outflow',
                value: CurrencyFormatter.formatVNDCompact(
                    summary.totalConfirmedOutflow),
                color: Colors.red.shade600,
              ),
              _MetricTile(
                label: 'Expected in',
                value: CurrencyFormatter.formatVNDCompact(
                    summary.totalExpectedInflow),
                color: Colors.green.shade600,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthScoreBadge extends StatelessWidget {
  final int score;
  final String label;
  final Color color;

  const _HealthScoreBadge({
    required this.score,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: score / 100,
                strokeWidth: 4,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Text(
                '$score',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _MetricTile(
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
          Text(value,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Balance Chart ──────────────────────────────────────────────────────────────

class _BalanceChart extends StatefulWidget {
  final List<DailyForecastModel> days;
  final void Function(int index) onTapDay;

  const _BalanceChart({required this.days, required this.onTapDay});

  @override
  State<_BalanceChart> createState() => _BalanceChartState();
}

class _BalanceChartState extends State<_BalanceChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final days = widget.days;

    // Build spot lists
    final safeSpots = <FlSpot>[];
    final expectedSpots = <FlSpot>[];
    for (int i = 0; i < days.length; i++) {
      safeSpots.add(FlSpot(i.toDouble(), days[i].closingBalanceSafe));
      expectedSpots
          .add(FlSpot(i.toDouble(), days[i].closingBalanceExpected));
    }

    final allValues = [
      ...safeSpots.map((s) => s.y),
      ...expectedSpots.map((s) => s.y),
    ];
    var minY = allValues.isEmpty
        ? 0.0
        : allValues.reduce((a, b) => a < b ? a : b);
    var maxY = allValues.isEmpty
        ? 1000000.0
        : allValues.reduce((a, b) => a > b ? a : b);

    if (maxY == minY) {
      if (maxY == 0) {
        maxY = 10000;
        minY = -10000;
      } else {
        final pad = maxY.abs() * 0.05;
        maxY += pad;
        minY -= pad;
      }
    } else {
      final diff = maxY - minY;
      if (diff < maxY.abs() * 0.02) {
        final pad = (maxY.abs() * 0.02 - diff) / 2;
        maxY += pad;
        minY -= pad;
      }
    }

    final yPad = (maxY - minY) * 0.15;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 12),
            child: Row(
              children: [
                _LegendDot(color: Colors.green.shade600, label: 'Safe balance'),
                const SizedBox(width: 16),
                _LegendDot(
                    color: Colors.blue.shade400, label: 'With expected in'),
              ],
            ),
          ),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: minY - yPad,
                maxY: maxY + yPad,
                clipData: const FlClipData.all(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4 == 0
                      ? 100000
                      : (maxY - minY) / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (v, _) => Text(
                        CurrencyFormatter.formatVNDCompact(v),
                        style: TextStyle(
                            fontSize: 9, color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: days.length > 14 ? 3 : 1,
                      getTitlesWidget: (value, _) {
                        final i = value.toInt();
                        if (i < 0 || i >= days.length) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime.tryParse(days[i].date);
                        if (date == null) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            DateFormat('dd/MM').format(date),
                            style: TextStyle(
                                fontSize: 9,
                                color: scheme.onSurfaceVariant),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Zero baseline (shown only if any balance < 0)
                extraLinesData: minY < 0
                    ? ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: 0,
                          color: Colors.red.shade400,
                          strokeWidth: 1.5,
                          dashArray: [6, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topLeft,
                            labelResolver: (_) => '  0',
                            style: TextStyle(
                                color: Colors.red.shade400, fontSize: 9),
                          ),
                        ),
                      ])
                    : null,
                lineTouchData: LineTouchData(
                  touchCallback:
                      (FlTouchEvent event, LineTouchResponse? response) {
                    if (event is FlTapUpEvent &&
                        response?.lineBarSpots != null &&
                        response!.lineBarSpots!.isNotEmpty) {
                      final idx =
                          response.lineBarSpots!.first.x.toInt();
                      setState(() => _touchedIndex = idx);
                      widget.onTapDay(idx);
                    }
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => scheme.surfaceContainerHigh,
                    getTooltipItems: (spots) => spots.map((s) {
                      final i = s.x.toInt();
                      final date = i < days.length
                          ? DateTime.tryParse(days[i].date)
                          : null;
                      return LineTooltipItem(
                        date != null
                            ? '${DateFormat('dd MMM').format(date)}\n'
                            : '',
                        TextStyle(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurface,
                            fontSize: 11),
                        children: [
                          TextSpan(
                            text: CurrencyFormatter.formatVNDCompact(s.y),
                            style: TextStyle(
                                color: s.bar.color ?? Colors.green,
                                fontWeight: FontWeight.w600,
                                fontSize: 11),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
                lineBarsData: [
                  // Safe line
                  LineChartBarData(
                    spots: safeSpots,
                    isCurved: true,
                    color: Colors.green.shade600,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      checkToShowDot: (spot, _) =>
                          spot.x.toInt() == _touchedIndex,
                      getDotPainter: (spot, percent, bar, index) =>
                          FlDotCirclePainter(
                              radius: 5,
                              color: Colors.green.shade600,
                              strokeWidth: 0),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Colors.green.shade600.withValues(alpha: 0.18),
                          Colors.green.shade600.withValues(alpha: 0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Expected line
                  LineChartBarData(
                    spots: expectedSpots,
                    isCurved: true,
                    color: Colors.blue.shade400,
                    barWidth: 1.5,
                    dashArray: [6, 4],
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

// ── Day Group ──────────────────────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  final DailyForecastModel day;
  final bool isHighlighted;
  const _DayGroup({required this.day, this.isHighlighted = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final date = DateTime.tryParse(day.date);
    if (date == null) return const SizedBox.shrink();

    final net = day.netChange;
    final netColor = net >= 0 ? Colors.green.shade600 : Colors.red.shade600;
    final formattedDate = _formatDayLabel(date);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? scheme.primaryContainer.withValues(alpha: 0.3)
            : scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? scheme.primary
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: isHighlighted ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  formattedDate,
                  style: textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                Text(
                  '${net >= 0 ? '+' : ''}${CurrencyFormatter.formatVNDCompact(net)} đ',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: netColor,
                      fontSize: 13),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Events
          ...day.allEvents.map((e) => _EventTile(event: e)),
          // Closing balance
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Text('Safe balance after:',
                    style: textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const Spacer(),
                Text(
                  CurrencyFormatter.formatVNDCompact(
                      day.closingBalanceSafe),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: day.isNegative
                          ? Colors.red.shade600
                          : Colors.blueGrey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDayLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today — ${DateFormat('dd MMM').format(date)}';
    if (d == today.add(const Duration(days: 1))) {
      return 'Tomorrow — ${DateFormat('dd MMM').format(date)}';
    }
    return DateFormat('EEE, dd MMM').format(date);
  }
}

class _EventTile extends StatelessWidget {
  final ForecastEventModel event;
  const _EventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final certColor = event.certaintyColor;

    return InkWell(
      onTap: () => EventDetailSheet.show(context, event),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            // Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: certColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                event.isSubscription
                    ? Icons.subscriptions_outlined
                    : event.sourceType == 'TRANSFER_OUT'
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                color: certColor,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    event.isSubscription
                        ? 'Subscription${event.groupName != null ? ' • ${event.groupName}' : ''}'
                        : 'Transfer${event.counterparty != null ? ' • ${event.counterparty}' : ''}',
                    style: textTheme.bodySmall
                        ?.copyWith(color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Amount + certainty badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${event.isOutflow ? '-' : '+'}${CurrencyFormatter.formatVNDCompact(event.amount)} đ',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: event.isOutflow
                          ? Colors.red.shade600
                          : Colors.green.shade600),
                ),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: certColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    event.certainty,
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: certColor),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right,
                size: 16, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
