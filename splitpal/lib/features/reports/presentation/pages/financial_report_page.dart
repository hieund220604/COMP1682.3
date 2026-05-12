import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../receipts/presentation/widgets/icon_helpers.dart';
import '../../report_provider.dart';
import '../../report_models.dart';
import '../../services/pdf_export_service.dart';

class FinancialReportPage extends StatefulWidget {
  const FinancialReportPage({super.key});
  @override
  State<FinancialReportPage> createState() => _FinancialReportPageState();
}

class _FinancialReportPageState extends State<FinancialReportPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedDate = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  void _loadData() {
    final p = context.read<ReportProvider>();
    final month =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}';
    p.fetchMonthlyReport(month);
    p.fetchYearlyReport(_selectedDate.year);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _pickMonth() async {
    final now = DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        int tempYear = _selectedDate.year;
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Select Month'),
                DropdownButton<int>(
                  value: tempYear,
                  underline: const SizedBox(),
                  items: List.generate(10, (i) => now.year - i)
                      .map((y) => DropdownMenuItem(value: y, child: Text(y.toString())))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => tempYear = v);
                  },
                ),
              ],
            ),
            content: SizedBox(
              width: 300,
              height: 250,
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 12,
                itemBuilder: (ctx, i) {
                  final month = i + 1;
                  final isSelected = month == _selectedDate.month && tempYear == _selectedDate.year;
                  final theme = Theme.of(context);
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      Navigator.pop(ctx, DateTime(tempYear, month));
                    },
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? theme.colorScheme.primary : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        DateFormat('MMM').format(DateTime(2000, month)),
                        style: TextStyle(
                          color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        });
      },
    );

    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Financial Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Monthly'), Tab(text: 'Yearly')],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export PDF',
            onPressed: () {
              final report = context.read<ReportProvider>().monthlyReport;
              if (report != null) {
                PdfExportService.generateAndShareFinancialReport(report);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No data to export')),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month),
            tooltip: 'Select Month',
            onPressed: _pickMonth,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MonthlyTab(selectedDate: _selectedDate),
          _YearlyTab(selectedYear: _selectedDate.year),
        ],
      ),
    );
  }
}

// ── MONTHLY TAB ──────────────────────────────────────────────────────────────

class _MonthlyTab extends StatelessWidget {
  final DateTime selectedDate;
  const _MonthlyTab({required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    if (provider.isMonthlyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.monthlyError != null) {
      return Center(child: Text('Error: ${provider.monthlyError}'));
    }
    final report = provider.monthlyReport;
    if (report == null) return const Center(child: Text('No data'));

    return RefreshIndicator(
      onRefresh: () => provider.fetchMonthlyReport(report.month),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MonthHeader(report: report),
          const SizedBox(height: 16),
          _OverviewCard(report: report),
          const SizedBox(height: 16),
          _CashflowChart(dailySpending: report.dailySpending),
          const SizedBox(height: 16),
          _SpendingHeatmap(
              dailySpending: report.dailySpending, month: report.month),
          const SizedBox(height: 16),
          _OutflowBreakdown(source: report.outflowBySource),
          const SizedBox(height: 16),
          _ComparisonCard(comparison: report.comparison),
          if (report.budgetPerformance.isNotEmpty) ...[
            const SizedBox(height: 16),
            _BudgetSection(items: report.budgetPerformance),
          ],
          if (report.groupActivity.isNotEmpty) ...[
            const SizedBox(height: 16),
            _GroupSection(items: report.groupActivity),
          ],
          if (report.subscriptionSummary.activeCount > 0) ...[
            const SizedBox(height: 16),
            _SubSection(summary: report.subscriptionSummary),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  final MonthlyReport report;
  const _MonthHeader({required this.report});

  @override
  Widget build(BuildContext context) {
    final parts = report.month.split('-');
    final dt = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    final label = DateFormat('MMMM yyyy').format(dt);
    return Text(label,
        style: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(fontWeight: FontWeight.w800));
  }
}

class _OverviewCard extends StatelessWidget {
  final MonthlyReport report;
  const _OverviewCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final o = report.overview;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text('Net Cashflow',
              style: TextStyle(
                  color: cs.onPrimary.withOpacity(0.8), fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            '${o.isPositive ? '+' : ''}${CurrencyFormatter.formatVND(o.netCashflow)}',
            style: TextStyle(
                color: cs.onPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _MiniStat(
                  icon: Icons.arrow_downward,
                  label: 'Income',
                  value: CurrencyFormatter.formatVNDCompact(o.totalInflow),
                  color: Colors.greenAccent),
              _MiniStat(
                  icon: Icons.arrow_upward,
                  label: 'Expense',
                  value: CurrencyFormatter.formatVNDCompact(o.totalOutflow),
                  color: Colors.redAccent),
              _MiniStat(
                  icon: Icons.receipt_long,
                  label: 'Txns',
                  value: '${o.transactionCount}',
                  color: Colors.white70),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _MiniStat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12)),
        Text(label,
            style: TextStyle(color: Colors.white70, fontSize: 10)),
      ]),
    );
  }
}

// ── DAILY CASHFLOW CHART (simple bar chart) ──────────────────────────────────

class _CashflowChart extends StatelessWidget {
  final List<DailySpending> dailySpending;
  const _CashflowChart({required this.dailySpending});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxVal = dailySpending.fold<double>(
        1, (m, d) => math.max(m, d.outflow + d.inflow));
    const chartHeight = 100.0;

    return _SectionCard(
      title: 'Daily Cashflow',
      child: SizedBox(
        height: chartHeight + 20,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: dailySpending.map((d) {
            final total = d.outflow + d.inflow;
            final ratio = maxVal > 0 ? (total / maxVal) : 0.0;
            final barH = ratio * chartHeight;
            final inFraction = total > 0 ? d.inflow / total : 0.0;
            final inH = barH * inFraction;
            final outH = barH - inH;
            final dayStr = d.date.split('-').last;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0.5),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: inH.clamp(0, chartHeight),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(2)),
                      ),
                    ),
                    Container(
                      height: outH.clamp(0, chartHeight),
                      decoration: BoxDecoration(
                        color: cs.error.withOpacity(0.6),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        dayStr,
                        style: TextStyle(
                          fontSize: 8,
                          color: cs.onSurface.withOpacity(0.5),
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ── OUTFLOW BREAKDOWN ────────────────────────────────────────────────────────

class _OutflowBreakdown extends StatelessWidget {
  final OutflowBySource source;
  const _OutflowBreakdown({required this.source});

  @override
  Widget build(BuildContext context) {
    final entries = source.entries;
    if (entries.isEmpty) return const SizedBox.shrink();
    final total = source.total;

    return _SectionCard(
      title: 'Where Money Goes',
      child: Column(
        children: entries.map((e) {
          final pct = total > 0 ? (e.amount / total * 100) : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(e.colorValue),
                    borderRadius: BorderRadius.circular(3),
                  )),
              const SizedBox(width: 8),
              Expanded(child: Text(e.label)),
              Text(CurrencyFormatter.formatVNDCompact(e.amount),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('${pct.round()}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                        fontSize: 12)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── COMPARISON CARD ──────────────────────────────────────────────────────────

class _ComparisonCard extends StatelessWidget {
  final ReportComparison comparison;
  const _ComparisonCard({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = comparison.changePercent.outflow;

    // Determine trend visuals: Improving = green/up, Declining = red/down
    final IconData icon;
    final Color color;
    final String trendLabel;

    if (comparison.isImproving) {
      icon = Icons.trending_up;
      color = Colors.green;
      trendLabel = '🎉 Improving';
    } else if (comparison.isDeclining) {
      icon = Icons.trending_down;
      color = Colors.redAccent;
      trendLabel = '⚠️ Declining';
    } else {
      icon = Icons.trending_flat;
      color = cs.onSurfaceVariant;
      trendLabel = '➡️ Stable';
    }

    return _SectionCard(
      title: 'vs. Last Month',
      child: Row(children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${pct > 0 ? '+' : ''}${pct.toStringAsFixed(1)}% spending',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: color, fontSize: 16),
              ),
              Text(trendLabel,
                  style: TextStyle(
                      color: cs.onSurfaceVariant, fontSize: 13)),
            ],
          ),
        ),
      ]),
    );
  }
}

// ── BUDGET SECTION ───────────────────────────────────────────────────────────

class _BudgetSection extends StatelessWidget {
  final List<BudgetPerformance> items;
  const _BudgetSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _SectionCard(
      title: 'Budget Performance',
      child: Column(
        children: items.map((b) {
          final progress = b.hasBudget
              ? (b.spent / b.budgetLimit!).clamp(0.0, 1.5)
              : 0.0;
          final barColor = b.isExceeded
              ? Colors.redAccent
              : b.isWarning
                  ? Colors.orange
                  : cs.primary;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(
                    materialIconToEmoji(b.tagIcon) ?? b.tagIcon,
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                      child: Text(b.tagName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13))),
                  Text(CurrencyFormatter.formatVNDCompact(b.spent),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: barColor)),
                ]),
                if (b.hasBudget) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: cs.surfaceContainerHighest,
                      color: barColor,
                      minHeight: 6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${b.percentUsed}% of ${CurrencyFormatter.formatVNDCompact(b.budgetLimit!)}',
                    style: TextStyle(
                        fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── GROUP SECTION ────────────────────────────────────────────────────────────

class _GroupSection extends StatelessWidget {
  final List<GroupActivity> items;
  const _GroupSection({required this.items});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Group Activity',
      child: Column(
        children: items.map((g) {
          final color = g.isPositive ? Colors.green : Colors.redAccent;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const Icon(Icons.group, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g.groupName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${g.invoiceCount} transactions',
                        style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant)),
                  ],
                ),
              ),
              Text(
                '${g.isPositive ? '+' : ''}${CurrencyFormatter.formatVNDCompact(g.netPosition)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: color),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ── SUBSCRIPTION SECTION ─────────────────────────────────────────────────────

class _SubSection extends StatelessWidget {
  final SubscriptionSummary summary;
  const _SubSection({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Subscriptions (${summary.activeCount} active)',
      child: Column(
        children: [
          ...summary.subscriptions.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  const Icon(Icons.autorenew, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(s.name)),
                  Text(CurrencyFormatter.formatVNDCompact(s.amount),
                      style:
                          const TextStyle(fontWeight: FontWeight.w600)),
                  Text(' /${_cycleLabel(s.cycle)}',
                      style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)),
                ]),
              )),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('This month total',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              Text(CurrencyFormatter.formatVND(summary.totalCost),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── YEARLY TAB ───────────────────────────────────────────────────────────────

class _YearlyTab extends StatelessWidget {
  final int selectedYear;
  const _YearlyTab({required this.selectedYear});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    if (provider.isYearlyLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.yearlyError != null) {
      return Center(child: Text('Error: ${provider.yearlyError}'));
    }
    final report = provider.yearlyReport;
    if (report == null) return const Center(child: Text('No data'));

    return RefreshIndicator(
      onRefresh: () => provider.fetchYearlyReport(selectedYear),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('$selectedYear Overview',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          _YearlyOverviewCard(overview: report.overview),
          const SizedBox(height: 16),
          _MonthlyBarChart(breakdown: report.monthlyBreakdown),
          if (report.topCategories.isNotEmpty) ...[
            const SizedBox(height: 16),
            _TopCategoriesCard(categories: report.topCategories),
          ],
          const SizedBox(height: 16),
          _YearlySummaryRow(report: report),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _YearlyOverviewCard extends StatelessWidget {
  final YearlyOverview overview;
  const _YearlyOverviewCard({required this.overview});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo, Colors.indigo.shade300],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(children: [
        Text('Yearly Net',
            style: TextStyle(color: Colors.white70, fontSize: 13)),
        Text(
          CurrencyFormatter.formatVND(overview.netCashflow),
          style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        Row(children: [
          _MiniStat(
              icon: Icons.arrow_downward,
              label: 'Total In',
              value: CurrencyFormatter.formatVNDCompact(overview.totalInflow),
              color: Colors.greenAccent),
          _MiniStat(
              icon: Icons.arrow_upward,
              label: 'Total Out',
              value: CurrencyFormatter.formatVNDCompact(overview.totalOutflow),
              color: Colors.redAccent),
          _MiniStat(
              icon: Icons.calendar_today,
              label: 'Avg/mo',
              value: CurrencyFormatter.formatVNDCompact(
                  overview.avgMonthlyOutflow),
              color: Colors.white70),
        ]),
      ]),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<MonthlyBreakdown> breakdown;
  const _MonthlyBarChart({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxVal = breakdown.fold<double>(
        1, (m, b) => math.max(m, math.max(b.outflow, b.inflow)));
    final months = [
      'J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'
    ];

    return _SectionCard(
      title: 'Monthly Trend',
      child: SizedBox(
        height: 140,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(12, (i) {
            final b = i < breakdown.length ? breakdown[i] : null;
            final outH = b != null ? (b.outflow / maxVal) * 100 : 0.0;
            final inH = b != null ? (b.inflow / maxVal) * 100 : 0.0;
            return Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    height: inH.clamp(0, 100),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.5),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(2)),
                    ),
                  ),
                  Container(
                    height: outH.clamp(0, 100),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: cs.error.withOpacity(0.5),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(months[i],
                      style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _TopCategoriesCard extends StatelessWidget {
  final List<TopCategory> categories;
  const _TopCategoriesCard({required this.categories});

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Top Spending Categories',
      child: Column(
        children: categories.map((c) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text(c.tagIcon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(child: Text(c.tagName)),
              Text(CurrencyFormatter.formatVNDCompact(c.totalSpent),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(
                width: 40,
                child: Text('${c.percent}%',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

class _YearlySummaryRow extends StatelessWidget {
  final YearlyReport report;
  const _YearlySummaryRow({required this.report});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: _SectionCard(
          title: 'Subs Total',
          child: Text(CurrencyFormatter.formatVNDCompact(report.subscriptionTotal),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _SectionCard(
          title: 'Group Total',
          child: Text(
              CurrencyFormatter.formatVNDCompact(report.groupExpenseTotal),
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
    ]);
  }
}

// ── SPENDING HEATMAP ─────────────────────────────────────────────────────────

class _SpendingHeatmap extends StatefulWidget {
  final List<DailySpending> dailySpending;
  final String month; // "2026-05"
  const _SpendingHeatmap({required this.dailySpending, required this.month});

  @override
  State<_SpendingHeatmap> createState() => _SpendingHeatmapState();
}

class _SpendingHeatmapState extends State<_SpendingHeatmap> {
  int? _tappedIndex;

  // Heatmap intensity colors (level 0-4)
  static const _heatColors = [
    Color(0x00000000), // 0: no spending — transparent
    Color(0xFF93E5AB), // 1: light green
    Color(0xFF4BC67E), // 2: medium green
    Color(0xFF1E9E52), // 3: strong green
    Color(0xFF0E6A33), // 4: dark green
  ];

  static const _anomalyBorder = Color(0xFFE53E3E);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final days = widget.dailySpending;

    if (days.isEmpty) return const SizedBox.shrink();

    // ── Compute stats ──────────────────────────────────────────────────────
    final outflows = days.map((d) => d.outflow).toList();
    final nonZero = outflows.where((o) => o > 0).toList()..sort();

    // Percentile thresholds for levels 1-4
    double p25 = 0, p50 = 0, p75 = 0;
    if (nonZero.isNotEmpty) {
      p25 = nonZero[(nonZero.length * 0.25).floor()];
      p50 = nonZero[(nonZero.length * 0.50).floor()];
      p75 = nonZero[(nonZero.length * 0.75).floor()];
    }

    // Anomaly detection: mean + 2σ
    final mean = nonZero.isEmpty
        ? 0.0
        : nonZero.fold<double>(0, (s, x) => s + x) / nonZero.length;
    final variance = nonZero.isEmpty
        ? 0.0
        : nonZero.fold<double>(0, (s, x) => s + (x - mean) * (x - mean)) /
            nonZero.length;
    final stddev = math.sqrt(variance);
    final anomalyThreshold = mean + 2 * stddev;

    // Assign level + anomaly flag per day
    final dayData = <_HeatmapDay>[];
    for (final d in days) {
      int level = 0;
      if (d.outflow > 0) {
        if (d.outflow <= p25) {
          level = 1;
        } else if (d.outflow <= p50) {
          level = 2;
        } else if (d.outflow <= p75) {
          level = 3;
        } else {
          level = 4;
        }
      }
      final isAnomaly =
          nonZero.length >= 5 && d.outflow > anomalyThreshold;
      dayData.add(_HeatmapDay(
        date: d.date,
        outflow: d.outflow,
        inflow: d.inflow,
        level: level,
        isAnomaly: isAnomaly,
      ));
    }

    // ── Pattern detection ───────────────────────────────────────────────────
    final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final weekdaySums = List<double>.filled(7, 0);
    final weekdayCounts = List<int>.filled(7, 0);
    int anomalyCount = 0;

    for (final d in dayData) {
      final dt = DateTime.tryParse(d.date);
      if (dt == null) continue;
      final wdi = dt.weekday - 1; // 0=Mon .. 6=Sun
      weekdaySums[wdi] += d.outflow;
      weekdayCounts[wdi] += 1;
      if (d.isAnomaly) anomalyCount++;
    }

    final weekdayAvgs = List.generate(7, (i) {
      return weekdayCounts[i] > 0 ? weekdaySums[i] / weekdayCounts[i] : 0.0;
    });
    final peakDayIdx = weekdayAvgs.indexOf(
        weekdayAvgs.reduce((a, b) => a > b ? a : b));

    final patterns = <String>[];
    if (nonZero.isNotEmpty &&
        weekdayAvgs[peakDayIdx] > mean * 1.3) {
      patterns.add('📈 Peak on ${weekdayNames[peakDayIdx]}s');
    }
    if (anomalyCount > 0) {
      patterns.add('⚠️ $anomalyCount anomal${anomalyCount == 1 ? 'y' : 'ies'}');
    }
    if (mean > 0) {
      patterns.add(
          '📊 Avg: ${CurrencyFormatter.formatVNDCompact(mean)}/day');
    }

    // ── Build grid ──────────────────────────────────────────────────────────
    // Determine first weekday of month to place cells correctly
    final parts = widget.month.split('-');
    final year = int.tryParse(parts[0]) ?? 2026;
    final monthNum = int.tryParse(parts[1]) ?? 1;
    final firstOfMonth = DateTime(year, monthNum, 1);
    final startWeekday = firstOfMonth.weekday - 1; // 0=Mon

    // Grid: leadingPadding + days
    final totalCells = startWeekday + dayData.length;
    final rows = (totalCells / 7).ceil();

    return _SectionCard(
      title: 'Spending Heatmap',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Weekday labels
          Row(
            children: weekdayNames
                .map((n) => Expanded(
                      child: Center(
                        child: Text(n,
                            style: TextStyle(
                                fontSize: 9,
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),

          // Heatmap grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 3,
              mainAxisSpacing: 3,
            ),
            itemCount: rows * 7,
            itemBuilder: (ctx, index) {
              final dayIndex = index - startWeekday;
              if (dayIndex < 0 || dayIndex >= dayData.length) {
                return const SizedBox.shrink();
              }

              final d = dayData[dayIndex];
              final isTapped = _tappedIndex == dayIndex;
              final color = _heatColors[d.level];
              final bgColor =
                  d.level == 0 ? cs.surfaceContainerHighest : color;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _tappedIndex = _tappedIndex == dayIndex ? null : dayIndex;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(4),
                    border: d.isAnomaly
                        ? Border.all(color: _anomalyBorder, width: 2)
                        : isTapped
                            ? Border.all(color: cs.primary, width: 1.5)
                            : null,
                    boxShadow: isTapped
                        ? [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                            )
                          ]
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      '${dayIndex + 1}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight:
                            d.level >= 3 ? FontWeight.w700 : FontWeight.w500,
                        color: d.level >= 3
                            ? Colors.white
                            : d.level >= 1
                                ? const Color(0xFF1B5E20)
                                : cs.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Tooltip for tapped day
          if (_tappedIndex != null &&
              _tappedIndex! >= 0 &&
              _tappedIndex! < dayData.length)
            _HeatmapTooltip(day: dayData[_tappedIndex!]),

          const SizedBox(height: 12),

          // Legend
          Row(
            children: [
              Text('Less',
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant)),
              const SizedBox(width: 6),
              ...List.generate(5, (i) {
                return Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: i == 0 ? cs.surfaceContainerHighest : _heatColors[i],
                    borderRadius: BorderRadius.circular(3),
                    border: i == 0
                        ? Border.all(
                            color: cs.outlineVariant, width: 0.5)
                        : null,
                  ),
                );
              }),
              const SizedBox(width: 6),
              Text('More',
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant)),
              const Spacer(),
              // Anomaly legend
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(color: _anomalyBorder, width: 2),
                ),
              ),
              const SizedBox(width: 4),
              Text('Anomaly',
                  style: TextStyle(
                      fontSize: 10, color: cs.onSurfaceVariant)),
            ],
          ),

          // Pattern chips
          if (patterns.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: patterns.map((p) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(p,
                      style: textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      )),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _HeatmapDay {
  final String date;
  final double outflow;
  final double inflow;
  final int level; // 0-4
  final bool isAnomaly;

  const _HeatmapDay({
    required this.date,
    required this.outflow,
    required this.inflow,
    required this.level,
    required this.isAnomaly,
  });
}

class _HeatmapTooltip extends StatelessWidget {
  final _HeatmapDay day;
  const _HeatmapTooltip({required this.day});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dt = DateTime.tryParse(day.date);
    final label = dt != null ? DateFormat('EEE, dd MMM').format(dt) : day.date;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          border: day.isAnomaly
              ? Border.all(
                  color: _SpendingHeatmapState._anomalyBorder.withValues(alpha: 0.4))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(label,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 13)),
                      if (day.isAnomaly) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: _SpendingHeatmapState._anomalyBorder
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('ANOMALY',
                              style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      _SpendingHeatmapState._anomalyBorder)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.arrow_upward, size: 12, color: Colors.red.shade400),
                      const SizedBox(width: 3),
                      Text(
                        CurrencyFormatter.formatVNDCompact(day.outflow),
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade600,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 12),
                      Icon(Icons.arrow_downward,
                          size: 12, color: Colors.green.shade400),
                      const SizedBox(width: 3),
                      Text(
                        CurrencyFormatter.formatVNDCompact(day.inflow),
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade600,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── SHARED SECTION CARD ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── HELPERS ──────────────────────────────────────────────────────────────────

String _cycleLabel(String cycle) {
  switch (cycle.toUpperCase()) {
    case 'DAILY':
      return 'day';
    case 'WEEKLY':
      return 'week';
    case 'MONTHLY':
      return 'month';
    case 'YEARLY':
      return 'year';
    default:
      return cycle.toLowerCase();
  }
}
