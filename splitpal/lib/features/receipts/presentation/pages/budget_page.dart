import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/receipts/receipt_provider.dart';
import 'package:splitpal/models/budget_summary.dart';
import 'package:splitpal/features/receipts/presentation/widgets/icon_helpers.dart';

import '../widgets/budget_modals.dart';

// ─── Sort Options ────────────────────────────────────────────────────────────
enum BudgetSortOption {
  nameAsc,
  nameDesc,
  spentDesc,
  spentAsc,
  budgetDesc,
  budgetAsc,
  progressDesc,
}

extension BudgetSortOptionLabel on BudgetSortOption {
  String get label {
    switch (this) {
      case BudgetSortOption.nameAsc:    return 'Name A → Z';
      case BudgetSortOption.nameDesc:   return 'Name Z → A';
      case BudgetSortOption.spentDesc:  return 'Most Spent';
      case BudgetSortOption.spentAsc:   return 'Least Spent';
      case BudgetSortOption.budgetDesc: return 'Highest Budget';
      case BudgetSortOption.budgetAsc:  return 'Lowest Budget';
      case BudgetSortOption.progressDesc: return 'Most Used %';
    }
  }

  IconData get icon {
    switch (this) {
      case BudgetSortOption.nameAsc:
      case BudgetSortOption.nameDesc:   return Icons.sort_by_alpha;
      case BudgetSortOption.spentDesc:
      case BudgetSortOption.spentAsc:   return Icons.payments_outlined;
      case BudgetSortOption.budgetDesc:
      case BudgetSortOption.budgetAsc:  return Icons.account_balance_wallet_outlined;
      case BudgetSortOption.progressDesc: return Icons.bar_chart;
    }
  }
}

// ─── Page ────────────────────────────────────────────────────────────────────
class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  DateTime _currentDate = DateTime.now();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  BudgetSortOption _sortOption = BudgetSortOption.nameAsc;
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    final monthStr =
        '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}';
    context.read<ReceiptProvider>().loadBudgetSummary(monthStr);
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentDate =
          DateTime(_currentDate.year, _currentDate.month + offset, 1);
    });
    _loadData();
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  List<BudgetSummary> _applyFilterSort(List<BudgetSummary> all) {
    // 1. Search filter
    var result = _searchQuery.isEmpty
        ? all
        : all
            .where((s) =>
                s.tag.name.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    // 2. Sort
    result.sort((a, b) {
      switch (_sortOption) {
        case BudgetSortOption.nameAsc:
          return a.tag.name.compareTo(b.tag.name);
        case BudgetSortOption.nameDesc:
          return b.tag.name.compareTo(a.tag.name);
        case BudgetSortOption.spentDesc:
          return b.spent.compareTo(a.spent);
        case BudgetSortOption.spentAsc:
          return a.spent.compareTo(b.spent);
        case BudgetSortOption.budgetDesc:
          return (b.tag.monthlyBudget ?? 0).compareTo(a.tag.monthlyBudget ?? 0);
        case BudgetSortOption.budgetAsc:
          return (a.tag.monthlyBudget ?? 0).compareTo(b.tag.monthlyBudget ?? 0);
        case BudgetSortOption.progressDesc:
          final pa = a.tag.monthlyBudget != null && a.tag.monthlyBudget! > 0
              ? a.spent / a.tag.monthlyBudget!
              : 0.0;
          final pb = b.tag.monthlyBudget != null && b.tag.monthlyBudget! > 0
              ? b.spent / b.tag.monthlyBudget!
              : 0.0;
          return pb.compareTo(pa);
      }
    });

    return result;
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.sort, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Sort By',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(),
            ...BudgetSortOption.values.map((opt) => ListTile(
                  leading: Icon(
                    opt.icon,
                    color: _sortOption == opt
                        ? Theme.of(ctx).colorScheme.primary
                        : null,
                  ),
                  title: Text(opt.label),
                  trailing: _sortOption == opt
                      ? Icon(Icons.check,
                          color: Theme.of(ctx).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() => _sortOption = opt);
                    Navigator.pop(ctx);
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    final allSummaries = provider.budgetSummary
        .map((e) => BudgetSummary.fromJson(e as Map<String, dynamic>))
        .toList();
    final summaries = _applyFilterSort(allSummaries);

    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search categories...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Budget Envelopes'),
        actions: [
          // Search toggle
          IconButton(
            icon: Icon(_showSearch ? Icons.close : Icons.search),
            tooltip: _showSearch ? 'Cancel' : 'Search',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          // Sort
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onPressed: _showSortSheet,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          showTagEditor(context);
        },
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: Column(
        children: [
          _buildMonthSelector(context),
          // Summary bar
          if (allSummaries.isNotEmpty) _buildSummaryBar(context, allSummaries),
          // Search results info
          if (_searchQuery.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    '${summaries.length} result${summaries.length != 1 ? 's' : ''} for "$_searchQuery"',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: provider.isLoadingBudget
                ? const Center(child: CircularProgressIndicator())
                : allSummaries.isEmpty
                    ? _buildEmptyState(context)
                    : summaries.isEmpty
                        ? _buildNoResults(context)
                        : RefreshIndicator(
                            onRefresh: () async => _loadData(),
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              itemCount: summaries.length,
                              itemBuilder: (context, index) {
                                return _BudgetCard(
                                  summary: summaries[index],
                                  onEdit: () =>
                                      showTagEditor(context, tag: summaries[index].tag),
                                  onDelete: () =>
                                      showTagDeleteConfirm(context, summaries[index].tag),
                                  onRefresh: _loadData,
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(BuildContext context, List<BudgetSummary> summaries) {
    final totalBudget = summaries
        .where((s) => s.tag.monthlyBudget != null)
        .fold<double>(0, (sum, s) => sum + (s.tag.monthlyBudget ?? 0));
    final totalSpent = summaries.fold<double>(0, (sum, s) => sum + s.spent);
    final overBudgetCount = summaries
        .where((s) =>
            s.tag.monthlyBudget != null && s.spent > s.tag.monthlyBudget!)
        .length;
    final usedRatio =
        totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.brandDark, AppColors.brand],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand.withAlpha(60),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryItem(
                  'Total Budget',
                  CurrencyFormatter.formatVND(totalBudget),
                  Icons.account_balance_wallet_outlined,
                ),
                Container(
                  width: 1,
                  height: 36,
                  color: Colors.white.withAlpha(60),
                ),
                _summaryItem(
                  'Total Spent',
                  CurrencyFormatter.formatVND(totalSpent),
                  Icons.payments_outlined,
                ),
                if (overBudgetCount > 0) ...[
                  Container(
                    width: 1,
                    height: 36,
                    color: Colors.white.withAlpha(60),
                  ),
                  _summaryItem(
                    'Over Limit',
                    '$overBudgetCount categor${overBudgetCount > 1 ? 'ies' : 'y'}',
                    Icons.warning_amber_rounded,
                    isWarning: true,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            // Overall progress
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: usedRatio,
                minHeight: 6,
                backgroundColor: Colors.white.withAlpha(50),
                valueColor: AlwaysStoppedAnimation<Color>(
                  overBudgetCount > 0
                      ? const Color(0xFFFFD6D6)
                      : Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(usedRatio * 100).toStringAsFixed(1)}% of total budget used',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, IconData icon,
      {bool isWarning = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: isWarning ? const Color(0xFFFFD6D6) : Colors.white70,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: isWarning ? const Color(0xFFFFD6D6) : Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
      ],
    );
  }

  Widget _buildMonthSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _changeMonth(-1),
          ),
          Text(
            '${_getMonthName(_currentDate.month)} ${_currentDate.year}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _changeMonth(1),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandDark, AppColors.brand],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withAlpha(80),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet_outlined,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No budget categories yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Track your spending via tags and budgets.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => showTagEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Setup Budgets'),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 16),
          Text('No results for "$_searchQuery"',
              style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
                _searchCtrl.clear();
                _showSearch = false;
              });
            },
            child: const Text('Clear search'),
          ),
        ],
      ),
    );
  }
}

// ─── Budget Card ─────────────────────────────────────────────────────────────
class _BudgetCard extends StatelessWidget {
  final BudgetSummary summary;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRefresh;

  const _BudgetCard({
    required this.summary,
    required this.onEdit,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBudget =
        summary.tag.monthlyBudget != null && summary.tag.monthlyBudget! > 0;

    double progress = 0;
    double percentage = 0;
    double remaining = 0;
    if (hasBudget) {
      progress = summary.spent / summary.tag.monthlyBudget!;
      percentage = progress * 100;
      remaining = summary.tag.monthlyBudget! - summary.spent;
      if (progress > 1) progress = 1;
    }

    final isOverBudget =
        hasBudget && summary.spent > summary.tag.monthlyBudget!;
    final today = DateTime.now();
    final endOfMonth = DateTime(today.year, today.month + 1, 0);
    final daysLeft = endOfMonth.day - today.day;
    final tagColor = _colorFromHex(summary.tag.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isOverBudget
              ? Colors.red.withAlpha(120)
              : theme.colorScheme.outlineVariant.withAlpha(80),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header row ──
            Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        tagColor.withAlpha(80),
                        tagColor.withAlpha(140),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      materialIconToEmoji(summary.tag.icon) ??
                          summary.tag.icon ??
                          '🏷️',
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Name + budget label
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.tag.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      if (hasBudget)
                        Text(
                          'Budget: ${CurrencyFormatter.formatVND(summary.tag.monthlyBudget!)}',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12),
                        )
                      else
                        Text(
                          'No budget set',
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 12,
                              fontStyle: FontStyle.italic),
                        ),
                    ],
                  ),
                ),
                // Spent amount
                Text(
                  CurrencyFormatter.formatVND(summary.spent),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isOverBudget ? Colors.red : null,
                  ),
                ),
                // Actions menu
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: theme.colorScheme.onSurfaceVariant, size: 20),
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_outlined, size: 18),
                        SizedBox(width: 10),
                        Text('Edit'),
                      ]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline,
                            size: 18, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ]),
                    ),
                  ],
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                  },
                ),
              ],
            ),

            // ── Progress bar ──
            if (hasBudget) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 10,
                  backgroundColor: AppColors.brandSurface,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget
                        ? theme.colorScheme.error
                        : (percentage >= 80
                            ? AppColors.brand
                            : AppColors.brandDark),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: isOverBudget
                          ? Colors.red
                          : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    isOverBudget
                        ? 'Over by ${CurrencyFormatter.formatVND(summary.spent - summary.tag.monthlyBudget!)}'
                        : '${CurrencyFormatter.formatVND(remaining)} left',
                    style: TextStyle(
                      color: isOverBudget
                          ? Colors.red
                          : theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (!isOverBudget && daysLeft >= 0)
                Text(
                  '$daysLeft days left',
                  style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11),
                  textAlign: TextAlign.right,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _colorFromHex(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}
