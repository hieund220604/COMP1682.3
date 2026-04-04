import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/groups/presentation/providers/group_provider.dart';
import '../../../../features/subscriptions/presentation/providers/subscription_provider.dart';
import '../../../../features/groups/presentation/pages/group_detail_page.dart';
import '../../../../features/subscriptions/presentation/pages/subscription_detail_page.dart';
import '../../../../features/home/presentation/pages/home_shell_page.dart';
import '../../../../features/exchange/presentation/pages/currency_converter_page.dart';
import '../../../../features/receipts/presentation/pages/receipt_calendar_page.dart';
import '../../../../features/receipts/presentation/pages/day_receipts_page.dart';
import '../../../../features/receipts/presentation/providers/receipt_provider.dart';
import 'transaction_history_page.dart';
import 'wallet_operations_page.dart';
import '../../../../core/di/injection_container.dart' as di;
import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with RouteAware {
  ModalRoute<dynamic>? _route;
  Map<String, dynamic>? _summary;
  bool _loading = false;
  String? _error;
  final DioClient _dio = di.sl<DioClient>();

  Future<void> _refreshData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await context.read<AuthProvider>().getCurrentUser(silent: true);
    if (!mounted) return;

    await Future.wait([
      context.read<GroupProvider>().fetchGroupsAndInvites(),
      context.read<SubscriptionProvider>().fetchSubscriptions(),
      _fetchDashboard(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _fetchDashboard() async {
    try {
      final response = await _dio.get(ApiConstants.dashboardHome);
      _summary = response.data['data'] as Map<String, dynamic>?;
    } catch (e) {
      _error = 'Không tải được dashboard';
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    _refreshData();
  }

  @override
  void didPopNext() {
    _refreshData();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(colorScheme: colorScheme, textTheme: textTheme),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _WalletBalanceCard(summary: _summary),
                    const SizedBox(height: 20),
                    _CashflowDashboard(summary: _summary),
                    const SizedBox(height: 20),
                    _DebtDashboard(summary: _summary),
                    const SizedBox(height: 20),
                    const _CurrencyConverterCard(),
                    const SizedBox(height: 20),
                    const _ReceiptDiarySection(),
                    const SizedBox(height: 20),
                    _SharedGroups(),
                    const SizedBox(height: 20),
                    const _SubscriptionForecastCard(),
                    const SizedBox(height: 20),
                    _UpcomingList(summary: _summary),
                    const SizedBox(height: 16),
                    // Removed _RecentTransactions
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: colorScheme.error)),
                    ],
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: LinearProgressIndicator(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _Header({required this.colorScheme, required this.textTheme});

  @override
  Widget build(BuildContext context) {
    final user = context.select((AuthProvider p) => p.user);
    final name = user?.displayName ?? 'User';
    final photoUrl = user?.avatarUrl;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28, // Slightly larger
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hi $name',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const _WalletBalanceCard({this.summary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final user = context.select((AuthProvider p) => p.user);
    final balance = (summary?['user']?['balance'] ?? user?.balance ?? 0.0).toDouble();
    final currency =
        summary?['user']?['currency'] ?? user?.currency ?? AppConstants.defaultCurrency;
    final balanceStr = '$currency ${balance.toStringAsFixed(2)}';

    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const TransactionHistoryPage(),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
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
                Icon(
                  Icons.account_balance_wallet,
                  color: colorScheme.onPrimary.withOpacity(0.8),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Wallet Balance',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimary.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.history,
                  color: colorScheme.onPrimary.withOpacity(0.9),
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              balanceStr,
              style: textTheme.displaySmall?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 32,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to view transaction history',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimary.withOpacity(0.85),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WalletOperationsPage(
                            mode: WalletOperationMode.topup,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_card),
                    label: const Text('Top up'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const WalletOperationsPage(
                            mode: WalletOperationMode.withdraw,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.outbox_outlined),
                    label: const Text('Withdraw'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedGroups extends StatelessWidget {
  const _SharedGroups();

  @override
  Widget build(BuildContext context) {
    // Consume GroupProvider
    final groups = context.select((GroupProvider p) => p.groups);

    return Column(
      children: [
        _SectionHeader(
          title: 'Shared Groups',
          actionLabel: 'See All',
          onAction: () {
            // Switch to Groups tab (index 2)
            SwitchTabNotification(2).dispatch(context);
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 170,
          child: groups.isEmpty
              ? const Center(child: Text('No active groups'))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(right: 8),
                  itemBuilder: (context, index) {
                    final g = groups[index];
                    // Map dynamic data
                    final name = g['name'] ?? 'Group';
                    final membersCount =
                        g['memberCount'] ??
                        (g['members'] as List?)?.length ??
                        0;
                    final groupId =
                        g['_id'] ?? g['id']; // Ensure ID is captured

                    return GestureDetector(
                      onTap: () {
                        if (groupId != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => GroupDetailPage(
                                groupId: groupId,
                                groupName: name,
                              ),
                            ),
                          );
                        }
                      },
                      child: Container(
                        width: 180,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).dividerColor.withOpacity(0.15),
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  height: 40,
                                  width: 40,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.apartment,
                                    color: Colors.blue,
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey,
                                  size: 14,
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Text(
                              name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$membersCount members',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemCount: groups.length,
                ),
        ),
      ],
    );
  }
}

class _SubscriptionForecastCard extends StatelessWidget {
  const _SubscriptionForecastCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final subscriptions = context.select(
      (SubscriptionProvider p) => p.subscriptions,
    );
    final isLoading = context.select((SubscriptionProvider p) => p.isLoading);

    final activeSubs = subscriptions
        .where((s) => s.status == 'ACTIVE' || s.status == 'PAST_DUE')
        .toList(growable: false);

    final currencies = activeSubs.map((s) => s.currency.toUpperCase()).toSet();
    final hasSingleCurrency = currencies.length == 1;
    final displayCurrency = hasSingleCurrency
        ? currencies.first
        : (context.select((AuthProvider p) => p.user?.currency) ??
              AppConstants.defaultCurrency);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    double overdueAmount = 0;
    final weekAmounts = List<double>.filled(4, 0);
    int overdueCount = 0;
    final weekCounts = List<int>.filled(4, 0);

    for (final sub in activeSubs) {
      final due = DateTime(
        sub.nextBillingDate.year,
        sub.nextBillingDate.month,
        sub.nextBillingDate.day,
      );

      final isOverdue = sub.status == 'PAST_DUE' || due.isBefore(today);
      if (isOverdue) {
        overdueAmount += sub.amount;
        overdueCount += 1;
        continue;
      }

      final days = due.difference(today).inDays;
      final weekIndex = days ~/ 7;
      if (weekIndex >= 0 && weekIndex < 4) {
        weekAmounts[weekIndex] += sub.amount;
        weekCounts[weekIndex] += 1;
      }
    }

    final amountValues = <double>[overdueAmount, ...weekAmounts];
    final countValues = <double>[
      overdueCount.toDouble(),
      ...weekCounts.map((c) => c.toDouble()),
    ];

    final values = hasSingleCurrency ? amountValues : countValues;
    final maxValue = values.fold<double>(0, (m, v) => math.max(m, v));
    final totalValue = values.fold<double>(0, (s, v) => s + v);

    String formatValue(double v) {
      if (!hasSingleCurrency) return v.toInt().toString();
      if (displayCurrency.toUpperCase() == 'VND') {
        return CurrencyFormatter.formatVNDCompact(v);
      }
      return CurrencyFormatter.formatCurrency(v, displayCurrency);
    }

    const labels = ['Overdue', 'W1', 'W2', 'W3', 'W4'];
    const opacities = [1.0, 0.85, 0.65, 0.50, 0.35];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(
            title: 'Forecast (4 weeks)',
            actionLabel: 'Subscriptions',
            onAction: () {
              SwitchTabNotification(1).dispatch(context);
            },
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(),
              ),
            )
          else if (activeSubs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No active subscriptions',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(labels.length, (index) {
                  final v = values[index];
                  final double ratio = maxValue <= 0 ? 0.0 : (v / maxValue);
                  final double barHeight = v == 0 ? 6.0 : (18.0 + ratio * 70.0);
                  final color = scheme.primary.withOpacity(opacities[index]);

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            formatValue(v),
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            labels[index],
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              hasSingleCurrency
                  ? 'Total due within 28 days: ${formatValue(totalValue)}'
                  : 'Multiple currencies detected, showing counts. Total due items within 28 days: ${totalValue.toInt()}',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UpcomingList extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const _UpcomingList({this.summary});

  @override
  Widget build(BuildContext context) {
    final subscriptions = context.select(
      (SubscriptionProvider p) => p.subscriptions,
    );
    final isLoading = context.select((SubscriptionProvider p) => p.isLoading);

    // Filter active subscriptions and sort by next billing date
    final upcomingSubs =
        subscriptions
            .where((sub) => sub.status == 'ACTIVE' || sub.status == 'PAST_DUE')
            .toList()
          ..sort((a, b) => a.nextBillingDate.compareTo(b.nextBillingDate));

    final openPRs = (summary?['openPaymentRequests'] as List?) ?? [];

    return Column(
      children: [
        _SectionHeader(
          title: 'Upcoming',
          actionLabel: upcomingSubs.length > 2 ? 'See All' : null,
          onAction: upcomingSubs.length > 2
              ? () {
                  // Switch to Subscriptions tab (index 1)
                  SwitchTabNotification(1).dispatch(context);
                }
              : null,
        ),
        const SizedBox(height: 8),
        if (openPRs.isNotEmpty) ...[
          const SizedBox(height: 8),
          Column(
            children: openPRs.map((pr) {
              final expiresAt = pr['expiresAt'] != null
                  ? DateTime.tryParse(pr['expiresAt'] as String)
                  : null;
              final issuedAt = pr['issuedAt'] != null
                  ? DateTime.tryParse(pr['issuedAt'] as String)
                  : null;
              final now = DateTime.now();
              final daysLeft = expiresAt != null
                  ? expiresAt.difference(now).inDays
                  : null;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.request_quote_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Payment Request ${pr['id']}', maxLines: 1),
                          if (issuedAt != null)
                            Text(
                              'Issued ${DateFormat('dd MMM').format(issuedAt)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    if (daysLeft != null)
                      Chip(
                        label: Text(
                          daysLeft < 0
                              ? 'Expired'
                              : '$daysLeft d left',
                          style: TextStyle(
                            color: daysLeft < 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                        ),
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceVariant,
                      ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
        if (isLoading)
          const Center(child: CircularProgressIndicator())
        else if (upcomingSubs.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('No upcoming subscriptions'),
            ),
          )
        else
          Column(
            children: upcomingSubs.take(3).map((sub) {
              final now = DateTime.now();
              final daysUntil = sub.nextBillingDate.difference(now).inDays;
              final isDueSoon = daysUntil <= 3;
              final statusText = sub.status == 'PAST_DUE'
                  ? 'Overdue'
                  : (isDueSoon ? 'Due soon' : 'Auto-pay');

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SubscriptionDetailPage(subscriptionId: sub.id),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.12),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('MMM').format(sub.nextBillingDate),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              DateFormat('dd').format(sub.nextBillingDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sub.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sub.description ?? sub.groupName ?? '',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${sub.currency} ${sub.amount.toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: sub.status == 'PAST_DUE'
                                  ? Colors.red
                                  : (isDueSoon
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: sub.status == 'PAST_DUE'
                              ? Colors.red
                              : (isDueSoon
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.grey),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (sub.status == 'PAST_DUE'
                                          ? Colors.red
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary)
                                      .withOpacity(0.4),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? action;

  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        action ??
            (actionLabel != null
                ? TextButton(
                    onPressed: onAction,
                    child: Text(
                      actionLabel!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  )
                : const SizedBox.shrink()),
      ],
    );
  }
}

/// Quick access card for currency converter
class _CurrencyConverterCard extends StatelessWidget {
  const _CurrencyConverterCard();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CurrencyConverterPage()),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.teal.shade400, Colors.teal.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.teal.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.currency_exchange,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Currency Converter',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Convert between 18+ currencies',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.7),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _CashflowDashboard extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const _CashflowDashboard({this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cashflow = summary?['cashflow7d'] as Map<String, dynamic>? ?? {};
    final inflow = (cashflow['inflow'] ?? 0).toDouble();
    final outflow = (cashflow['outflow'] ?? 0).toDouble();
    final total = inflow + outflow;
    final inflowPct = total == 0 ? 0.0 : (inflow / total).clamp(0.0, 1.0);

    final numFormat = NumberFormat.compactCurrency(symbol: '', decimalDigits: 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cashflow (7d)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Inflow', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                   Text(numFormat.format(inflow), style: TextStyle(color: scheme.tertiary, fontWeight: FontWeight.bold, fontSize: 16)),
                ]
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text('Outflow', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                   Text(numFormat.format(outflow), style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold, fontSize: 16)),
                ]
              ),
            ]
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
               height: 8,
               child: total == 0 ? Container(color: scheme.surfaceVariant) : Row(
                 children: [
                   if (inflowPct > 0) Expanded(flex: (inflowPct * 1000).toInt(), child: Container(color: scheme.tertiary)),
                   if (inflowPct < 1) Expanded(flex: ((1 - inflowPct) * 1000).toInt(), child: Container(color: scheme.error)),
                 ]
               )
            )
          )
        ]
      )
    );
  }
}

class _DebtDashboard extends StatelessWidget {
  final Map<String, dynamic>? summary;
  const _DebtDashboard({this.summary});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final debts = summary?['debts'] as Map<String, dynamic>? ?? {};
    final youOwe = (debts['youOwe'] ?? 0).toDouble();
    final theyOwe = (debts['theyOwe'] ?? 0).toDouble();
    final total = youOwe + theyOwe;
    final youOwePct = total == 0 ? 0.0 : (youOwe / total).clamp(0.0, 1.0);

    final numFormat = NumberFormat.compactCurrency(symbol: '', decimalDigits: 1);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Debt Summary', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('You Owe', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                   Text(numFormat.format(youOwe), style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold, fontSize: 16)),
                ]
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   Text('They Owe You', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
                   Text(numFormat.format(theyOwe), style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                ]
              ),
            ]
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
               height: 8,
               child: total == 0 ? Container(color: scheme.surfaceVariant) : Row(
                 children: [
                   if (youOwePct > 0) Expanded(flex: (youOwePct * 1000).toInt(), child: Container(color: scheme.error)),
                   if (youOwePct < 1) Expanded(flex: ((1 - youOwePct) * 1000).toInt(), child: Container(color: scheme.primary)),
                 ]
               )
            )
          )
        ]
      )
    );
  }
}

class _ReceiptDiarySection extends StatefulWidget {
  const _ReceiptDiarySection();

  @override
  State<_ReceiptDiarySection> createState() => _ReceiptDiarySectionState();
}

class _ReceiptDiarySectionState extends State<_ReceiptDiarySection> {
  DateTime _month = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  void _load() {
    final provider = context.read<ReceiptProvider>();
    provider.loadTags();
    provider.loadMonth(_formatMonth(_month));
  }

  String _formatMonth(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}';

  String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Consumer<ReceiptProvider>(
      builder: (context, provider, _) {
        final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
        final firstWeekday = DateTime(_month.year, _month.month, 1).weekday; // 1=Mon
        final summaryMap = {for (var s in provider.monthSummary) s.date: s};

        final tiles = <Widget>[];
        for (int i = 1; i < firstWeekday; i++) {
          tiles.add(const SizedBox.shrink());
        }
        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(_month.year, _month.month, day);
          final dateStr = _formatDate(date);
          final summary = summaryMap[dateStr];
          tiles.add(_DayPreviewTile(
            day: day,
            count: summary?.count ?? 0,
            thumbUrls: summary?.thumbUrls ?? const [],
            isToday: DateUtils.isSameDay(date, DateTime.now()),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DayReceiptsPage(date: dateStr, selectedTagIds: const {}),
              ),
            ),
          ));
        }

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                  Text('Receipt diary', style: textTheme.titleMedium),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ReceiptCalendarPage()),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open full view'),
                  ),
                  ],
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() => _month = DateTime(_month.year, _month.month - 1, 1));
                      _load();
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_month.year} - ${_month.month.toString().padLeft(2, '0')}',
                        style: textTheme.titleLarge,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() => _month = DateTime(_month.year, _month.month + 1, 1));
                      _load();
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              provider.isLoadingMonth
                  ? const Center(child: CircularProgressIndicator())
                  : GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      children: tiles,
                    ),
            ],
          ),
        );
      },
    );
  }
}

class _DayPreviewTile extends StatelessWidget {
  final int day;
  final int count;
  final List<String> thumbUrls;
  final bool isToday;
  final VoidCallback onTap;

  const _DayPreviewTile({
    required this.day,
    required this.count,
    required this.thumbUrls,
    required this.isToday,
    required this.onTap,
  });

  String _fixUrl(String url) {
    if (url.contains('localhost')) {
      return url.replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isToday ? scheme.primary : scheme.outlineVariant),
          gradient: count > 0
              ? const LinearGradient(
                  colors: [Color(0xFFe0e7ff), Color(0xFFc7d2fe)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (thumbUrls.isNotEmpty)
              Stack(
                children: List.generate(
                  thumbUrls.length.clamp(0, 3),
                  (index) {
                    final reversedIndex = thumbUrls.length.clamp(0, 3) - 1 - index;
                    return Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(
                          left: reversedIndex * 4.0,
                          top: reversedIndex * 4.0,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white, width: 1.0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11),
                              child: Image.network(
                                _fixUrl(thumbUrls[index]),
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ).reversed.toList(),
              ),
            Align(
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: count > 0 ? Colors.black : scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            if (count > 1)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 11),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// End of file
