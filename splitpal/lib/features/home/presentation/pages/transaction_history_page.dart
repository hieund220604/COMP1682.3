import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/api_constants.dart';
import 'package:splitpal/core/app_services.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency_formatter.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  static const int _pageSize = 20;

  final DioClient _dioClient = AppServices.dio;

  final List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _total = 0;

  bool get _hasMore => _transactions.length < _total;

  @override
  void initState() {
    super.initState();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
      _total = 0;
      _transactions.clear();
    });

    try {
      final response = await _dioClient.get(
        ApiConstants.transactions,
        queryParameters: {'page': 1, 'limit': _pageSize},
      );

      final data = response.data['data'];
      final rows = (data is Map<String, dynamic> && data['transactions'] is List)
          ? (data['transactions'] as List)
          : <dynamic>[];

      final parsed = rows
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      setState(() {
        _transactions.addAll(parsed);
        _total = (data is Map<String, dynamic> && data['total'] is num)
            ? (data['total'] as num).toInt()
            : parsed.length;
        _page = 1;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load transaction history. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _page + 1;
      final response = await _dioClient.get(
        ApiConstants.transactions,
        queryParameters: {'page': nextPage, 'limit': _pageSize},
      );

      final data = response.data['data'];
      final rows = (data is Map<String, dynamic> && data['transactions'] is List)
          ? (data['transactions'] as List)
          : <dynamic>[];

      final parsed = rows
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      setState(() {
        _transactions.addAll(parsed);
        _total = (data is Map<String, dynamic> && data['total'] is num)
            ? (data['total'] as num).toInt()
            : _total;
        _page = nextPage;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load more transactions.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction History'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitial,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _loadInitial,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_transactions.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 140),
          Center(child: Text('No transactions yet')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _transactions.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        if (index == _transactions.length) {
          if (!_hasMore) {
            return const SizedBox(height: 8);
          }

          return Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _isLoadingMore
                  ? const CircularProgressIndicator()
                  : OutlinedButton(
                      onPressed: _loadMore,
                      child: const Text('Load more'),
                    ),
            ),
          );
        }

        final item = _transactions[index];
        return _TransactionCard(item: item);
      },
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _TransactionCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final type = (item['type'] as String? ?? '').trim();
    final amountRaw = item['amount'];
    final double amount = _safeDouble(amountRaw);
    final currency = (item['currency'] as String? ?? 'VND').trim();
    final description = _localizedDescription((item['description'] as String?)?.trim());
    final createdAtRaw = item['createdAt'] as String?;

    final createdAt = createdAtRaw != null
        ? DateTime.tryParse(createdAtRaw)?.toLocal()
        : null;

    final isIncome = _isIncomeType(type);
    final amountColor = isIncome ? Colors.green : Colors.red;
    final sign = isIncome ? '+' : '-';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.2)),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _displayType(type),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              Text(
                '$sign${CurrencyFormatter.formatCurrency(amount, currency)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: amountColor,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                createdAt != null
                    ? DateFormat('dd/MM/yyyy HH:mm').format(createdAt)
                    : 'Unknown time',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                'Balance: ${CurrencyFormatter.formatCurrency(_safeDouble(item['balanceAfter']), currency)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  static bool _isIncomeType(String type) {
    switch (type) {
      case 'TOP_UP':
      case 'TRANSFER_RECEIVED':
      case 'TRANSFER_REFUND_RECEIVED':
      case 'REFUND':
      case 'DEPOSIT':
      case 'SETTLEMENT_RECEIVED':
        return true;
      default:
        return false;
    }
  }

  static String _displayType(String type) {
    switch (type) {
      case 'TOP_UP':
        return 'Top up';
      case 'WITHDRAWAL':
        return 'Withdraw';
      case 'TRANSFER_SENT':
        return 'Transfer sent';
      case 'TRANSFER_RECEIVED':
        return 'Transfer received';
      case 'TRANSFER_REFUND_SENT':
        return 'Refund sent';
      case 'TRANSFER_REFUND_RECEIVED':
        return 'Refund received';
      case 'VNPAY_PAYMENT':
        return 'VNPay payment';
      case 'EXPENSE_PAYMENT':
        return 'Expense payment';
      case 'SUBSCRIPTION_FEE':
        return 'Subscription fee';
      case 'REFUND':
        return 'Refund';
      case 'DEPOSIT':
        return 'Deposit';
      case 'SETTLEMENT_SENT':
        return 'Settlement sent';
      case 'SETTLEMENT_RECEIVED':
        return 'Settlement received';
      default:
        return type.isEmpty ? 'Transaction' : type;
    }
  }

  static String? _localizedDescription(String? input) {
    if (input == null || input.isEmpty) return input;

    String output = input;

    output = output.replaceFirst(RegExp(r'^Tru tien hoan cho\s+', caseSensitive: false), 'Refund sent to ');
    output = output.replaceFirst(RegExp(r'^Hoan tien tu\s+', caseSensitive: false), 'Refund from ');
    output = output.replaceFirst(RegExp(r'huy payment request', caseSensitive: false), 'payment request cancelled');
    output = output.replaceFirst(RegExp(r'^Nhan tu\s+', caseSensitive: false), 'Received from ');
    output = output.replaceFirst(RegExp(r'^Nap tien qua VNPay$', caseSensitive: false), 'Top up via VNPay');
    output = output.replaceFirst(RegExp(r'^Thanh toan cho\s+', caseSensitive: false), 'Payment to ');
    output = output.replaceFirst(RegExp(r'^Tra no cho\s+', caseSensitive: false), 'Paid debt to ');
    output = output.replaceFirst(RegExp(r'^Rut tien ve\s+', caseSensitive: false), 'Withdrawal to ');

    return output;
  }
}

double _safeDouble(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  if (v is Map) {
    final dec = v['\$numberDecimal'] ?? v['numberDecimal'];
    if (dec != null) return double.tryParse(dec.toString()) ?? 0.0;
  }
  return 0.0;
}
