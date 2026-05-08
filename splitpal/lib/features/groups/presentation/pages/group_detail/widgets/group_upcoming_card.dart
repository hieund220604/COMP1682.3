import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_card.dart';

class GroupUpcomingCard extends StatelessWidget {
  final Map<String, dynamic> upcoming;
  final String currency;

  const GroupUpcomingCard({
    super.key,
    required this.upcoming,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final paymentRequests = (upcoming['paymentRequests'] as List?) ?? [];

    if (paymentRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                'Upcoming',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Payment requests
          if (paymentRequests.isNotEmpty) ...[
            Text(
              'Expiring Payment Requests',
              style: textTheme.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ...paymentRequests.map((pr) {
              final id = (pr['id'] ?? '').toString();
              final daysLeft = _sn(pr['daysLeft'])?.toInt() ?? 0;
              final expiresAtStr = pr['expiresAt'] as String?;
              final expiresAt = expiresAtStr != null ? DateTime.tryParse(expiresAtStr) : null;

              final urgencyColor = daysLeft <= 2
                  ? Colors.red.shade600
                  : daysLeft <= 5
                      ? Colors.orange.shade600
                      : scheme.onSurfaceVariant;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: urgencyColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.receipt_long_outlined,
                        size: 18,
                        color: urgencyColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PR #${id.length > 8 ? id.substring(0, 8) : id}',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (expiresAt != null)
                            Text(
                              'Expires ${DateFormat('dd MMM yyyy').format(expiresAt)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: urgencyColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        daysLeft <= 0 ? 'Today' : '${daysLeft}d left',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: urgencyColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

}

num? _sn(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  if (v is Map) {
    final d = v['\$numberDecimal'] ?? v['numberDecimal'];
    if (d != null) return num.tryParse(d.toString());
  }
  return null;
}
