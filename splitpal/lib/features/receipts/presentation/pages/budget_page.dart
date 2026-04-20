import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/receipts/receipt_provider.dart';
import 'package:splitpal/models/budget_summary.dart';

import '../widgets/budget_modals.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  DateTime _currentDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    final monthStr = '${_currentDate.year}-${_currentDate.month.toString().padLeft(2, '0')}';
    context.read<ReceiptProvider>().loadBudgetSummary(monthStr);
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentDate = DateTime(_currentDate.year, _currentDate.month + offset, 1);
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    final summaries = provider.budgetSummary
        .map((e) => BudgetSummary.fromJson(e as Map<String, dynamic>))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Envelopes'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showTagEditor(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Category'),
      ),
      body: Column(
        children: [
          _buildMonthSelector(context),
          Expanded(
            child: provider.isLoadingBudget
                ? const Center(child: CircularProgressIndicator())
                : summaries.isEmpty
                    ? _buildEmptyState(context)
                    : RefreshIndicator(
                        onRefresh: () async => _loadData(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: summaries.length,
                          itemBuilder: (context, index) {
                            return _BudgetCard(summary: summaries[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
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
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.primary.withAlpha(100),
          ),
          const SizedBox(height: 16),
          const Text(
            'No budget categories yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Track your spending via tags and budgets.'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => showTagEditor(context),
            icon: const Icon(Icons.add),
            label: const Text('Setup Budgets'),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final BudgetSummary summary;

  const _BudgetCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasBudget = summary.tag.monthlyBudget != null && summary.tag.monthlyBudget! > 0;
    
    double progress = 0;
    double percentage = 0;
    double remaining = 0;
    if (hasBudget) {
      progress = summary.spent / summary.tag.monthlyBudget!;
      percentage = progress * 100;
      remaining = summary.tag.monthlyBudget! - summary.spent;
      if (progress > 1) progress = 1;
    }

    final isOverBudget = hasBudget && summary.spent > summary.tag.monthlyBudget!;
    
    final today = DateTime.now();
    final endOfMonth = DateTime(today.year, today.month + 1, 0);
    final daysLeft = endOfMonth.day - today.day;

    return GestureDetector(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Category'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showTagEditor(context, tag: summary.tag);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete Category', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(ctx);
                    showTagDeleteConfirm(context, summary.tag);
                  },
                ),
              ],
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isOverBudget 
                ? Colors.red.withAlpha(100) 
                : theme.colorScheme.outlineVariant.withAlpha(100),
          ),
        ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _colorFromHex(summary.tag.color).withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(summary.tag.icon ?? '🏷️', style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.tag.name.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (hasBudget)
                        Text(
                          'Budget: ${CurrencyFormatter.formatVND(summary.tag.monthlyBudget!)}',
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.formatVND(summary.spent),
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: isOverBudget ? Colors.red : null,
                  ),
                ),
              ],
            ),
            if (hasBudget) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isOverBudget ? Colors.red : _colorFromHex(summary.tag.color),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: isOverBudget ? Colors.red : theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    isOverBudget 
                        ? 'Over by ${CurrencyFormatter.formatVND(summary.spent - summary.tag.monthlyBudget!)}'
                        : '${CurrencyFormatter.formatVND(remaining)} left',
                    style: TextStyle(
                      color: isOverBudget ? Colors.red : theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!isOverBudget)
                Text(
                  '$daysLeft days left until end of month',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                  textAlign: TextAlign.right,
                ),
            ]
          ],
        ),
      ),
    ));
  }
}

Color _colorFromHex(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}
