import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/features/groups/presentation/providers/group_provider.dart';
import 'package:splitpal/features/subscriptions/domain/entities/subscription.dart';
import 'package:splitpal/features/subscriptions/presentation/providers/subscription_provider.dart';
import 'package:splitpal/features/subscriptions/presentation/pages/subscription_detail_page.dart';

class SubscriptionsPage extends StatefulWidget {
  const SubscriptionsPage({super.key});

  @override
  State<SubscriptionsPage> createState() => _SubscriptionsPageState();
}

class _SubscriptionsPageState extends State<SubscriptionsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => context.read<SubscriptionProvider>().fetchSubscriptions(),
    );
  }

  Future<void> _processCharges() async {
    final provider = context.read<SubscriptionProvider>();
    final result = await provider.processCharges();
    if (!mounted) return;
    final msg = provider.error ??
        'Processed charges: ${result?['successfulCharges'] ?? 0}/${result?['totalSubscriptions'] ?? 0} succeeded';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateSubscriptionSheet(),
    );
  }

  Future<void> _cancelSub(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel subscription'),
        content: const Text('Are you sure you want to cancel this subscription?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel subscription'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final provider = context.read<SubscriptionProvider>();
    final ok = await provider.cancel(id);
    if (!mounted) return;

    if (!ok) {
      // Show snackbar – list stays intact
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.actionError ?? 'Failed to cancel subscription'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      provider.clearActionError();
    } else {
      // Refresh list to reflect updated status
      provider.fetchSubscriptions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        title: const Text('Subscriptions'),
        actions: [
          IconButton(
            tooltip: 'Process charges',
            icon: const Icon(Icons.refresh),
            onPressed: _processCharges,
          ),
        ],
      ),
      body: Consumer<SubscriptionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.error!, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: provider.fetchSubscriptions,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final subs = provider.subscriptions;
          if (subs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('No subscriptions yet'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _openCreateSheet,
                    child: const Text('Create subscription'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: provider.fetchSubscriptions,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              itemCount: subs.length,
              itemBuilder: (context, index) {
                final sub = subs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SubscriptionCard(
                    subscription: sub,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SubscriptionDetailPage(subscriptionId: sub.id),
                      ),
                    ),
                    onCancel: sub.status == 'CANCELLED'
                        ? null
                        : () => _cancelSub(sub.id),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).colorScheme.primary,
        onPressed: _openCreateSheet,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: const SizedBox.shrink(), // handled by shell
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  const _SubscriptionCard({
    required this.subscription,
    required this.onTap,
    this.onCancel,
  });

  Color _statusColor(BuildContext context) {
    switch (subscription.status) {
      case 'ACTIVE':
        return Colors.green;
      case 'PAUSED':
        return Colors.orange;
      case 'CANCELLED':
        return Colors.red;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.12)),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${subscription.amount.toStringAsFixed(0)} ${subscription.currency} / ${subscription.billingCycle.toLowerCase()}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _statusColor(context).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    subscription.status,
                    style: TextStyle(
                      color: _statusColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(
                      'Next: ${_fmtDate(subscription.nextBillingDate)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
                if (onCancel != null)
                  TextButton(
                    onPressed: onCancel,
                    style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _CreateSubscriptionSheet extends StatefulWidget {
  const _CreateSubscriptionSheet();

  @override
  State<_CreateSubscriptionSheet> createState() => _CreateSubscriptionSheetState();
}

class _CreateSubscriptionSheetState extends State<_CreateSubscriptionSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();

  List<dynamic> _groups = [];
  String? _selectedGroupId;
  String _billingCycle = 'MONTHLY';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Preload groups so user can pick existing one
    Future.microtask(() async {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isEmpty) {
        await groupProvider.fetchGroupsAndInvites();
      }
      setState(() {
        _groups = groupProvider.groups;
        if (_groups.isNotEmpty) {
          _selectedGroupId = _extractGroupId(_groups.first);
        }
      });
    });
  }

  String? _extractGroupId(dynamic group) {
    if (group is Map) {
      return (group['id'] ?? group['_id'] ?? group['groupId'])?.toString();
    }
    return null;
  }

  String _extractGroupName(dynamic group) {
    if (group is Map) {
      return (group['name'] ?? group['groupName'] ?? _extractGroupId(group) ?? 'Unnamed').toString();
    }
    return group.toString();
  }

  Future<void> _submit() async {
    final provider = context.read<SubscriptionProvider>();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim());

    if (_nameController.text.trim().isEmpty || _selectedGroupId == null || amount == null) {
      setState(() => _error = 'Please enter name, select a group, and a valid amount');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final ok = await provider.create(
      groupId: _selectedGroupId!,
      name: _nameController.text.trim(),
      amount: amount,
      billingCycle: _billingCycle,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      startDate: _parseDate(_startDateController.text.trim()),
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = provider.error ?? 'Create failed';
        _submitting = false;
      });
    }
  }

  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        bottom: viewInsets,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create subscription',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const SizedBox(height: 8),
            _buildField('Service name', _nameController, hint: 'Netflix, Spotify...'),
            _buildGroupDropdown(),
            _buildField('Amount', _amountController, hint: 'e.g. 99000'),
            _buildDropdown(),
            _buildField('Description (optional)', _descriptionController, hint: ''),
            _buildField('Start date ISO (optional)', _startDateController,
                hint: '2026-01-28T00:00:00Z'),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Billing cycle', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _billingCycle,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
              DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
              DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
            ],
            onChanged: (val) => setState(() => _billingCycle = val ?? 'MONTHLY'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupDropdown() {
    final isLoadingGroups = _groups.isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Group', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _selectedGroupId,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: isLoadingGroups
                ? const [
                    DropdownMenuItem(value: null, child: Text('Loading groups...')),
                  ]
                : _groups
                    .map((g) => DropdownMenuItem<String>(
                          value: _extractGroupId(g),
                          child: Text(_extractGroupName(g)),
                        ))
                    .toList(),
            onChanged: isLoadingGroups ? null : (val) => setState(() => _selectedGroupId = val),
          ),
          if (isLoadingGroups)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }
}
