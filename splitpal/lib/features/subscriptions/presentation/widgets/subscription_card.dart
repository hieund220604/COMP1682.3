import 'package:flutter/material.dart';
import 'package:splitpal/models/subscription.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback onTap;
  final VoidCallback? onCancel;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    required this.onTap,
    this.onCancel,
  });

  Color _statusColor(BuildContext context) {
    switch (subscription.status) {
      case 'ACTIVE':
        return Colors.green;
      case 'PAST_DUE':
        return Colors.orange.shade800; // Updated to match recent changes
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
