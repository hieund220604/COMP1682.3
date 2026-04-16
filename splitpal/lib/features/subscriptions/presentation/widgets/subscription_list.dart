import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/features/subscriptions/subscription_provider.dart';
import '../pages/subscription_detail_page.dart';
import 'subscription_card.dart';
import 'create_subscription_sheet.dart';

class SubscriptionList extends StatefulWidget {
  final String? groupId;

  const SubscriptionList({super.key, this.groupId});

  @override
  State<SubscriptionList> createState() => _SubscriptionListState();
}

class _SubscriptionListState extends State<SubscriptionList> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<SubscriptionProvider>().fetchSubscriptions());
  }

  void _openCreateSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreateSubscriptionSheet(initialGroupId: widget.groupId),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SubscriptionProvider>(
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
        
        final allSubs = provider.subscriptions;
        final subs = widget.groupId != null 
            ? allSubs.where((s) => s.groupId == widget.groupId).toList()
            : allSubs;

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
                child: SubscriptionCard(
                  subscription: sub,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          SubscriptionDetailPage(subscriptionId: sub.id),
                    ),
                  ),
                  onCancel: sub.status == 'CANCELLED'
                      ? null
                      : () => context
                          .read<SubscriptionProvider>()
                          .cancel(sub.id),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
