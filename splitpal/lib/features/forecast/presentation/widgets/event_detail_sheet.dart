import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/forecast/forecast_provider.dart';
import 'package:splitpal/features/subscriptions/presentation/pages/subscription_detail_page.dart';

class EventDetailSheet extends StatelessWidget {
  final ForecastEventModel event;

  const EventDetailSheet({super.key, required this.event});

  static void show(BuildContext context, ForecastEventModel event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDetailSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final certColor = event.certaintyColor;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Row(
            children: [
              _SourceIcon(event: event),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (event.counterparty != null)
                      Text(
                        event.counterparty!,
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),

          // Info rows
          _InfoRow(
            icon: Icons.calendar_today_outlined,
            label: 'Due date',
            value: DateFormat('dd MMM yyyy').format(event.effectiveDate),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.payments_outlined,
            label: 'Amount',
            value: CurrencyFormatter.formatCurrency(
                event.amount, event.currency),
            valueColor:
                event.isOutflow ? Colors.red.shade600 : Colors.green.shade600,
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.category_outlined,
            label: 'Type',
            value: event.isSubscription
                ? 'Subscription charge'
                : event.sourceType == 'TRANSFER_OUT'
                    ? 'Outgoing payment'
                    : 'Incoming payment',
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.verified_outlined,
            label: 'Certainty',
            value: event.certainty,
            valueColor: certColor,
          ),
          if (event.groupName != null) ...[
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.group_outlined,
              label: 'Group',
              value: event.groupName!,
            ),
          ],

          const SizedBox(height: 28),

          // CTA
          if (event.isSubscription)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // sourceId for a subscription event is "sub_member_{memberId}"
                  // We extract the memberId and navigate — the detail page
                  // fetches subscription info by subscriptionId from the member.
                  // Here we navigate using the sourceId directly; the page
                  // accepts subscriptionId, so we pass what we have and let the
                  // server sort it out. The API returns sourceId = memberId, so
                  // we strip the prefix to get the raw mongo id.
                  final rawId = event.sourceId;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          SubscriptionDetailPage(subscriptionId: rawId),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('View Subscription'),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.info_outline, size: 18),
                label: const Text('Transfer details coming soon'),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceIcon extends StatelessWidget {
  final ForecastEventModel event;
  const _SourceIcon({required this.event});

  @override
  Widget build(BuildContext context) {
    final color = event.certaintyColor;
    final icon = event.isSubscription
        ? Icons.subscriptions_outlined
        : event.sourceType == 'TRANSFER_OUT'
            ? Icons.arrow_upward_rounded
            : Icons.arrow_downward_rounded;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.onSurfaceVariant),
        const SizedBox(width: 12),
        Text(
          label,
          style: textTheme.bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const Spacer(),
        Text(
          value,
          style: textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
