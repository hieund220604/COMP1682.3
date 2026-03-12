import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/features/auth/presentation/providers/auth_provider.dart';
import 'package:splitpal/features/subscriptions/domain/entities/subscription.dart';
import 'package:splitpal/features/subscriptions/presentation/providers/subscription_provider.dart';

class SubscriptionDetailPage extends StatefulWidget {
  final String subscriptionId;

  const SubscriptionDetailPage({super.key, required this.subscriptionId});

  @override
  State<SubscriptionDetailPage> createState() => _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState extends State<SubscriptionDetailPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final provider = context.read<SubscriptionProvider>();
      provider.fetchSubscription(widget.subscriptionId);
      provider.fetchBillingHistory(widget.subscriptionId);
    });
  }

  // ── Action helpers ────────────────────────────────────────────────────────

  Future<void> _cancel(SubscriptionProvider provider, Subscription sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription'),
        content: const Text('This cannot be undone. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await provider.cancel(sub.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Subscription cancelled' : (provider.actionError ?? 'Cancel failed')),
      backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
    ));
    if (!ok) provider.clearActionError();
  }

  Future<void> _resume(SubscriptionProvider provider, Subscription sub) async {
    final ok = await provider.resume(sub.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Subscription resumed' : (provider.actionError ?? 'Resume failed')),
      backgroundColor: ok ? null : Theme.of(context).colorScheme.error,
    ));
    if (!ok) provider.clearActionError();
  }

  Future<void> _leave(SubscriptionProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave subscription'),
        content: const Text(
          'You will no longer be charged for this subscription. Your share will be redistributed to remaining members.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Stay'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await provider.leave(widget.subscriptionId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You left the subscription')),
      );
      Navigator.of(context).pop(); // Go back to list
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.actionError ?? 'Failed to leave'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      provider.clearActionError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription details'),
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, _) {
          if (provider.isDetailLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final sub = provider.selected;
          if (sub == null) {
            return Center(
              child: Text(provider.error ?? 'Subscription not found'),
            );
          }

          // Determine current user's role in this subscription
          final authProvider = context.read<AuthProvider>();
          final currentUserId = authProvider.user?.id;
          final isCreator = sub.createdBy == currentUserId;
          final isMember = sub.members.any((m) => m.userId == currentUserId && m.status == 'ACTIVE');
          final canManage = isCreator; // Only creator (OWNER/ADMIN) can cancel/pause/resume

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        sub.name,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    Chip(
                      label: Text(sub.status),
                      backgroundColor: _statusColor(sub.status).withValues(alpha: 0.12),
                      labelStyle: TextStyle(
                        color: _statusColor(sub.status),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(sub.description ?? 'No description'),
                const SizedBox(height: 16),

                // ── Info ────────────────────────────────────────────────────
                _info('Amount', '${sub.amount.toStringAsFixed(0)} ${sub.currency}'),
                _info('Billing cycle', sub.billingCycle),
                _info('Next billing', _fmt(sub.nextBillingDate)),
                if (sub.lastBilledAt != null) _info('Last billed', _fmt(sub.lastBilledAt!)),
                _info('Group', sub.groupName ?? sub.groupId),
                _info('Created by', sub.createdByName ?? sub.createdBy),
                _info('Created at', _fmt(sub.createdAt)),
                const SizedBox(height: 16),

                // ── Members ─────────────────────────────────────────────────
                const Text('Members', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...sub.members.map(
                  (m) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      child: Text((m.displayName ?? m.email ?? '?').characters.first.toUpperCase()),
                    ),
                    title: Text(m.displayName ?? m.email ?? m.userId),
                    subtitle: Text('Share: ${m.shareAmount} · ${m.status}'),
                  ),
                ),

                // ── PAST_DUE warning ────────────────────────────────────────
                if (sub.status == 'PAST_DUE') ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Payment Overdue',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                        const SizedBox(height: 4),
                        Text('Retry count: ${sub.retryCount}/3'),
                        if (sub.failureReason != null)
                          Text('Reason: ${sub.failureReason}'),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Action buttons ──────────────────────────────────────────
                if (provider.isProcessing)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  // Cancel (ACTIVE only + canManage)
                  if (sub.status == 'ACTIVE' && canManage)
                    _actionButton(
                      label: 'Cancel Subscription',
                      color: Theme.of(context).colorScheme.error,
                      onPressed: () => _cancel(provider, sub),
                    ),

                  // Resume (PAST_DUE only + canManage)
                  if (sub.status == 'PAST_DUE' && canManage)
                    _actionButton(
                      label: 'Resume Subscription',
                      color: Colors.green,
                      onPressed: () => _resume(provider, sub),
                    ),

                  // Leave (member but not creator, ACTIVE only)
                  if (!isCreator && isMember && sub.status == 'ACTIVE')
                    _actionButton(
                      label: 'Leave Subscription',
                      color: Colors.blueGrey,
                      onPressed: () => _leave(provider),
                    ),
                ],

                const SizedBox(height: 32),

                // ── Billing History ─────────────────────────────────────────
                const Text(
                  'Billing History',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                if (provider.isBillingHistoryLoading)
                  const Center(child: CircularProgressIndicator())
                else if (provider.billingHistory.isEmpty)
                  const Text('No billing history yet.',
                      style: TextStyle(color: Colors.grey))
                else
                  ...provider.billingHistory.map((record) => _billingHistoryTile(record)),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
          ),
          child: Text(label),
        ),
      ),
    );
  }

  Widget _billingHistoryTile(Map<String, dynamic> record) {
    final status = (record['status'] ?? '').toString();
    final billedAt = record['billedAt'] != null
        ? _fmt(DateTime.tryParse(record['billedAt'].toString()) ?? DateTime.now())
        : '—';
    final amount = record['amount']?.toString() ?? '—';
    final isSuccess = status == 'SUCCESS';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isSuccess
            ? Colors.green.withValues(alpha: 0.07)
            : Colors.red.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isSuccess ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                billedAt,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                'Amount: $amount',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green : Colors.red,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _info(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';

  Color _statusColor(String status) {
    switch (status) {
      case 'ACTIVE':
        return Colors.green;
      case 'PAST_DUE':
        return Colors.orange.shade800;
      case 'PAUSED':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }
}
