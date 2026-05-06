import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/models/receipt.dart';
import 'package:splitpal/features/receipts/receipt_provider.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'day_receipts_page.dart';
import 'budget_page.dart';
import 'budget_page.dart';
import '../widgets/add_receipt_bottom_sheet.dart';

class ReceiptCalendarPage extends StatefulWidget {
  static const routeName = '/receipts';

  const ReceiptCalendarPage({super.key});

  @override
  State<ReceiptCalendarPage> createState() => _ReceiptCalendarPageState();
}

class _ReceiptCalendarPageState extends State<ReceiptCalendarPage> {
  DateTime _currentMonth = DateTime.now();
  final Set<String> _selectedTagIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ReceiptProvider>();
      provider.loadTags();
      _loadMonth(provider);
    });
  }

  void _loadMonth(ReceiptProvider provider) {
    final monthStr = _formatMonth(_currentMonth);
    provider.loadMonth(monthStr);
  }

  String _formatMonth(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadMonth(context.read<ReceiptProvider>());
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadMonth(context.read<ReceiptProvider>());
  }

  void _openAddSheet({DateTime? defaultDate}) {
    final provider = context.read<ReceiptProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: AddReceiptBottomSheet(
          defaultDate: defaultDate ?? DateTime.now(),
          onCreated: () {
            _loadMonth(provider);
          },
        ),
      ),
    );
  }

  void _openTagManager() async {
    final provider = context.read<ReceiptProvider>();
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const BudgetPage()),
    );
    if (changed == true) {
      provider.loadTags();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // 1=Mon

    // build map for quick lookup
    final summaryMap = {for (var s in provider.monthSummary) s.date: s};

    List<Widget> tiles = [];
    // pad to start on Monday
    for (int i = 1; i < firstWeekday; i++) {
      tiles.add(const SizedBox.shrink());
    }
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, day);
      final dateStr = _formatDate(date);
      final summary = summaryMap[dateStr];
      final count = summary?.count ?? 0;
      final thumbUrls = summary?.thumbUrls ?? const [];
      tiles.add(_DayTile(
        day: day,
        count: count,
        thumbUrls: thumbUrls,
        isToday: DateUtils.isSameDay(date, DateTime.now()),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DayReceiptsPage(date: dateStr, selectedTagIds: _selectedTagIds),
            ),
          );
          _loadMonth(provider);
        },
      ));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt diary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.pie_chart_outline),
            tooltip: 'Budget Envelopes',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const BudgetPage()),
              ).then((_) => _loadMonth(provider));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_currentMonth.year} - ${_currentMonth.month.toString().padLeft(2, '0')}',
                      style: textTheme.titleLarge,
                    ),
                  ),
                ),
                IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
              ],
            ),
            const SizedBox(height: 8),
            // Monthly total
            if (!provider.isLoadingMonth)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total this month',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatVND(provider.monthSummary.fold<double>(
                        0, (sum, s) => sum + s.totalAmount,
                      )),
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: provider.isLoadingMonth
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.count(
                      crossAxisCount: 7,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: tiles,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayTile extends StatelessWidget {
  final int day;
  final int count;
  final List<String> thumbUrls;
  final bool isToday;
  final VoidCallback onTap;

  const _DayTile({
    required this.day,
    required this.count,
    required this.thumbUrls,
    required this.isToday,
    required this.onTap,
  });

  String _fixUrl(String url) {
    if (!kIsWeb && Platform.isAndroid && url.contains('localhost')) {
      return url.replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isToday ? colorScheme.primary : colorScheme.outlineVariant),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbUrls.isNotEmpty)
              Stack(
                children: List.generate(
                  thumbUrls.length.clamp(0, 3),
                  (index) {
                    // Reverse index so the first image is on top
                    final reversedIndex = thumbUrls.length.clamp(0, 3) - 1 - index;
                    return Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: reversedIndex * 6.0,
                          top: reversedIndex * 6.0,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 1.5),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10.5),
                              child: Image.network(
                                _fixUrl(thumbUrls[index]),
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                                errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ).reversed.toList(),
              )
            else if (count > 0)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE0E7FF), Color(0xFFC7D2FE)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [Colors.black54, Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            Align(
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: count > 0 ? Colors.white : colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: SizedBox(
                  width: 32,
                  height: 16,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(
                      count.clamp(1, 3),
                      (i) => Positioned(
                        right: i * 8.0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.85 - i * 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          alignment: Alignment.center,
                          child: i == 0 && count > 1
                              ? Text(
                                  '$count',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
