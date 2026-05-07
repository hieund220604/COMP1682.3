import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/features/auth/auth_provider.dart';
import 'package:splitpal/features/groups/group_provider.dart';
import 'package:splitpal/models/subscription.dart';
import 'package:splitpal/features/receipts/receipt_provider.dart';
import 'package:splitpal/features/subscriptions/subscription_provider.dart';
import 'package:splitpal/features/subscriptions/presentation/widgets/subscription_invite_sheet.dart';

class SubscriptionDetailPage extends StatefulWidget {
  final String subscriptionId;

  const SubscriptionDetailPage({super.key, required this.subscriptionId});

  @override
  State<SubscriptionDetailPage> createState() => _SubscriptionDetailPageState();
}

class _SubscriptionDetailPageState extends State<SubscriptionDetailPage> {
  String? _selectedTagId;
  bool _isResponding = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      final provider = context.read<SubscriptionProvider>();
      provider.fetchSubscription(widget.subscriptionId);
      provider.fetchBillingHistory(widget.subscriptionId);
      context.read<ReceiptProvider>().loadTags();
    });
  }

  // ── Action helpers ─────────────────────────────────────────────────────────

  Future<void> _respond(SubscriptionProvider provider, String invitationId, bool accept) async {
    setState(() => _isResponding = true);
    final ok = await provider.respondToInvitation(
      subscriptionId: widget.subscriptionId,
      invitationId: invitationId,
      accept: accept,
      categoryTagId: _selectedTagId,
    );
    if (!mounted) return;
    setState(() => _isResponding = false);
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok 
        ? (accept ? 'You joined the subscription' : 'Invitation declined')
        : (provider.actionError ?? 'Failed to respond')),
      backgroundColor: ok ? Colors.green : Theme.of(context).colorScheme.error,
    ));
    if (!ok) provider.clearActionError();
  }

  Future<void> _cancel(SubscriptionProvider provider, Subscription sub) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription'),
        content: const Text(
          'This will end the subscription for all members. No refunds. Are you sure?',
        ),
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

  Future<void> _leave(SubscriptionProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave subscription'),
        content: const Text(
          'If you have not paid for the current cycle, you will be charged before leaving.',
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
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(provider.actionError ?? 'Failed to leave'),
        backgroundColor: Theme.of(context).colorScheme.error,
      ));
      provider.clearActionError();
    }
  }

  void _showInviteSheet(
    BuildContext context,
    SubscriptionProvider provider,
    Subscription sub,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SubscriptionInviteSheet(subscription: sub),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Details'),
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

          final authProvider = context.read<AuthProvider>();
          final currentUserId = authProvider.user?.id;
          final isCreator = sub.createdBy == currentUserId;
          final isMember = sub.members
              .any((m) => m.userId == currentUserId && m.isActive);

          // Find current user's member record for per-member billing info
          final myMember = sub.members
              .cast<SubscriptionMember?>()
              .firstWhere(
                (m) => m?.userId == currentUserId,
                orElse: () => null,
              );
              
          final myInvitation = sub.pendingInvitations
              .cast<SubInvitation?>()
              .firstWhere(
                (inv) => inv?.inviteeId == currentUserId && inv?.status == 'PENDING',
                orElse: () => null,
              );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ────────────────────────────────────────────────────
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

                // ── Subscription info ────────────────────────────────────────
                _info('Fee per member',
                    '${sub.amount.toStringAsFixed(0)} ${sub.currency} / ${sub.billingCycle.toLowerCase()}'),
                _info('Billing cycle', sub.billingCycle),
                if (sub.groupId != null)
                  _info('Group', sub.groupName ?? sub.groupId ?? ''),
                _info('Created by', sub.createdByName ?? sub.createdBy),
                _info('Created at', _fmt(sub.createdAt)),
                if (sub.cancelledAt != null)
                  _info('Cancelled at', _fmt(sub.cancelledAt!)),
                const SizedBox(height: 8),

                // ── My billing info ───────────────────────────────────────────
                if (myMember != null && myMember.isActive) ...[
                  const Divider(),
                  const Text('My Billing',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  _info('My fee', '${myMember.amount.toStringAsFixed(0)} ${sub.currency}'),
                  _info('Next charge', _fmt(myMember.nextBillingDate)),
                  _info('Last charged', _fmt(myMember.lastChargedAt)),
                  if (myMember.retryCount > 0)
                    _infoWarning('Failed attempts', '${myMember.retryCount}/3'),
                  const SizedBox(height: 8),
                ],

                // ── Members ───────────────────────────────────────────────────
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Members (${sub.memberCount} active)',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (isCreator && sub.isActive)
                      TextButton.icon(
                        onPressed: () => _showInviteSheet(context, provider, sub),
                        icon: const Icon(Icons.person_add, size: 18),
                        label: const Text('Invite'),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                ...sub.members.where((m) => m.isActive).map(
                      (m) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            (m.displayName ?? m.email ?? '?')
                                .characters
                                .first
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(m.displayName ?? m.email ?? m.userId),
                        subtitle: Text(
                          '${m.amount.toStringAsFixed(0)} ${sub.currency} · Next: ${_fmt(m.nextBillingDate)}',
                        ),
                        trailing: m.retryCount > 0
                            ? Tooltip(
                                message: '${m.retryCount} failed attempt(s)',
                                child: const Icon(Icons.warning_amber,
                                    color: Colors.orange, size: 18),
                              )
                            : null,
                      ),
                    ),

                // ── Respond to Invitation ─────────────────────────────────────
                if (myInvitation != null) ...[
                  const Divider(),
                  const Text('You have been invited to join this subscription.', 
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 12),
                  
                  // Tag selector
                  Consumer<ReceiptProvider>(
                    builder: (context, receiptProvider, _) {
                      final tags = receiptProvider.tags;
                      if (tags.isEmpty) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: DropdownButton<String>(
                          value: _selectedTagId,
                          hint: const Text('Select Budget Envelope (Optional)', style: TextStyle(fontSize: 14)),
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: [
                            const DropdownMenuItem<String>(
                              value: null,
                              child: Text('No Envelope'),
                            ),
                            ...tags.map((t) => DropdownMenuItem(
                                  value: t.id,
                                  child: Text('${t.icon} ${t.name}'),
                                )),
                          ],
                          onChanged: (val) => setState(() => _selectedTagId = val),
                        ),
                      );
                    },
                  ),
                  
                  if (_isResponding)
                    const Center(child: CircularProgressIndicator())
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _respond(provider, myInvitation.id, false),
                            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                            child: const Text('Decline'),
                          )
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _respond(provider, myInvitation.id, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Accept'),
                          )
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                ],

                // ── Pending invitations ───────────────────────────────────────
                if (isCreator && sub.pendingInvitations.isNotEmpty) ...[
                  const Divider(),
                  const Text('Pending Invitations',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  ...sub.pendingInvitations.map(
                    (inv) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                          child: Icon(Icons.mail_outline, size: 18)),
                      title: Text(
                          inv.inviteeDisplayName ?? inv.inviteeEmail ?? inv.inviteeId),
                      subtitle: const Text('Awaiting response'),
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // ── Action buttons ────────────────────────────────────────────
                if (provider.isProcessing)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  if (sub.isActive && isCreator)
                    _actionButton(
                      label: 'Cancel Subscription',
                      color: Theme.of(context).colorScheme.error,
                      onPressed: () => _cancel(provider, sub),
                    ),
                  if (!isCreator && isMember && sub.isActive)
                    _actionButton(
                      label: 'Leave Subscription',
                      color: Colors.blueGrey,
                      onPressed: () => _leave(provider),
                    ),
                ],

                const SizedBox(height: 32),

                // ── Billing History ───────────────────────────────────────────
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
    final billingDate = record['billingDate'] != null
        ? _fmt(DateTime.tryParse(record['billingDate'].toString()) ?? DateTime.now())
        : '—';
    final amount = record['totalCollected']?.toString() ?? record['amount']?.toString() ?? '—';
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
                billingDate,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                'Collected: $amount VND',
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
          SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _infoWarning(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(color: Colors.orange))),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, color: Colors.orange)),
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
      case 'CANCELLED':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }
}
