import 'package:flutter/material.dart';

import 'package:splitpal/core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/widgets/app_metric_tile.dart';
import 'package:splitpal/features/groups/presentation/pages/group_detail/widgets/members_preview_card.dart';

class GroupOverviewTab extends StatelessWidget {
  final String groupId;
  final String groupName;
  final List<dynamic> members;
  final Map<String, dynamic>? balance;
  final String currency;
  final String? role;
  final bool isOwnerOrAdmin;
  final Map<String, dynamic>? dashboard;

  final Future<void> Function() onRefresh;
  final VoidCallback onOpenChat;
  final VoidCallback? onInvite;
  final VoidCallback? onCreateInvoice;
  final Future<void> Function()? onCreatePaymentRequest;
  final VoidCallback? onCreateSubscription;
  final Future<void> Function(String memberId)? onTransferOwnership;
  final Future<void> Function(String memberId, String role)? onUpdateMemberRole;

  const GroupOverviewTab({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.members,
    required this.balance,
    required this.currency,
    required this.role,
    required this.isOwnerOrAdmin,
    this.dashboard,
    required this.onRefresh,
    required this.onOpenChat,
    this.onInvite,
    this.onCreateInvoice,
    this.onCreatePaymentRequest,
    this.onCreateSubscription,
    this.onTransferOwnership,
    this.onUpdateMemberRole,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final totalSpent = (balance?['totalSpent'] ?? 0).toDouble();
    final netBalance = (balance?['netBalance'] ?? 0).toDouble();

    final netLabel = netBalance == 0
        ? 'SETTLED'
        : netBalance < 0
            ? 'YOU OWE'
            : 'YOU GET BACK';
    final netColor = netBalance == 0
        ? scheme.tertiary
        : netBalance < 0
            ? scheme.error
            : scheme.tertiary;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          140,
        ),
        children: [
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (role != null) _RolePill(role: role!),
                    const Spacer(),
                    Text(
                      '${members.length} members',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: AppMetricTile(
                        label: 'TOTAL SPENT',
                        value: CurrencyFormatter.formatCurrency(
                          totalSpent,
                          currency,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: AppMetricTile(
                        label: netLabel,
                        value: CurrencyFormatter.formatCurrency(
                          netBalance.abs(),
                          currency,
                        ),
                        valueColor: netColor,
                      ),
                    ),
                  ],
                ),
                if (netBalance != 0) ...[
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Settle up is coming soon'),
                        ),
                      );
                    },
                    icon: const Icon(AppIcons.payments),
                    label: const Text('Settle up'),
                    style: FilledButton.styleFrom(
                      backgroundColor: scheme.primary.withAlpha(18),
                      foregroundColor: scheme.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Quick actions', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _QuickActionButton(
                icon: AppIcons.chat,
                label: 'Chat',
                onPressed: onOpenChat,
              ),
              if (onInvite != null)
                _QuickActionButton(
                  icon: AppIcons.memberAdd,
                  label: 'Invite',
                  onPressed: onInvite!,
                ),
              if (onCreateInvoice != null)
                _QuickActionButton(
                  icon: AppIcons.add,
                  label: 'New invoice',
                  onPressed: onCreateInvoice!,
                ),
              if (onCreatePaymentRequest != null)
                _QuickActionButton(
                  icon: AppIcons.payments,
                  label: 'Payment request',
                  onPressed: () => onCreatePaymentRequest!(),
                ),
              if (onCreateSubscription != null)
                _QuickActionButton(
                  icon: AppIcons.subscriptions,
                  label: 'New subscription',
                  onPressed: onCreateSubscription!,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (dashboard != null) ...[
            _PaymentRequestOverview(dashboard: dashboard!),
            const SizedBox(height: AppSpacing.lg),
            _TransferPendingCard(dashboard: dashboard!),
            const SizedBox(height: AppSpacing.lg),
            _RecentTransfersCard(dashboard: dashboard!, members: members),
            const SizedBox(height: AppSpacing.lg),
          ],
          MembersPreviewCard(
            members: members,
            currentUserRole: role,
            onViewAll: members.length <= 5
                ? null
                : () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => MembersBottomSheet(
                        members: members,
                        currentUserRole: role,
                        onTransferOwnership: onTransferOwnership,
                        onUpdateMemberRole: onUpdateMemberRole,
                      ),
                    );
                  },
            onTransferOwnership: onTransferOwnership,
            onUpdateMemberRole: onUpdateMemberRole,
          ),
        ],
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  final String role;

  const _RolePill({required this.role});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final label = _roleLabel(role);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.pomegranate.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.pomegranate),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: AppColors.pomegranate,
        ),
      ),
    );
  }
}

class _PaymentRequestOverview extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  const _PaymentRequestOverview({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prs = (dashboard['paymentRequests'] as List?) ?? [];
    if (prs.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment requests', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...prs.map((pr) {
            final double total = (pr['totalAmount'] ?? 0).toDouble();
            final double collected = (pr['collectedAmount'] ?? 0).toDouble();
            final double pct = total == 0 ? 0 : (collected / total).clamp(0, 1);
            final expiresAt = pr['expiresAt'] != null
                ? DateTime.tryParse(pr['expiresAt'] as String)
                : null;
            final daysLeft =
                expiresAt != null ? expiresAt.difference(DateTime.now()).inDays : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('PR ${pr['id']}'.substring(0, 8)),
                    const Spacer(),
                    if (daysLeft != null)
                      Chip(
                        backgroundColor: scheme.surfaceVariant,
                        label: Text(
                          daysLeft < 0 ? 'Expired' : '$daysLeft d left',
                          style: TextStyle(
                            color: daysLeft < 0 ? scheme.error : scheme.onSurface,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: pct,
                  minHeight: 6,
                  color: scheme.primary,
                  backgroundColor: scheme.surfaceVariant,
                ),
                const SizedBox(height: 4),
                Text('${collected.toStringAsFixed(0)} / ${total.toStringAsFixed(0)}'),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _TransferPendingCard extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  const _TransferPendingCard({required this.dashboard});

  @override
  Widget build(BuildContext context) {
    final pending = dashboard['transfersPending'] as Map<String, dynamic>? ?? {};
    final total = (pending['totalAmount'] ?? 0).toDouble();
    final count = pending['count'] ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pending transfers', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Text('$count items'),
            ],
          ),
          Text(total.toStringAsFixed(0)),
        ],
      ),
    );
  }
}

class _RecentTransfersCard extends StatelessWidget {
  final Map<String, dynamic> dashboard;
  final List<dynamic> members;
  const _RecentTransfersCard({
    required this.dashboard,
    required this.members,
  });

  String _getMemberName(dynamic id) {
    if (id == null) return 'Unknown';
    try {
      final member = members.firstWhere((m) {
        final user = m['user'];
        return user != null && (user['id'] == id || user['_id'] == id);
      }, orElse: () => null);
      if (member != null && member['user'] != null) {
        return member['user']['displayName'] ??
            member['user']['name'] ??
            id.toString();
      }
    } catch (_) {}
    return id.toString();
  }

  @override
  Widget build(BuildContext context) {
    final list = (dashboard['recentTransfers'] as List?) ?? [];
    if (list.isEmpty) return const SizedBox.shrink();
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Recent transfers', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...list.map((t) {
            final createdAt = t['createdAt'] != null
                ? DateTime.tryParse(t['createdAt'] as String)
                : null;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(AppIcons.payments),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'From ${_getMemberName(t['fromUserId'])} to ${_getMemberName(t['toUserId'])}'),
                        if (createdAt != null)
                          Text(
                            DateFormat('dd MMM, HH:mm').format(createdAt),
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
                  Text('${t['amount']}'),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

String _roleLabel(String raw) {
  switch (raw.toUpperCase()) {
    case 'OWNER':
      return 'Owner';
    case 'ADMIN':
      return 'Admin';
    case 'USER':
    case 'MEMBER':
      return 'Member';
    default:
      return raw;
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.pomegranate.withOpacity(0.12),
        foregroundColor: AppColors.pomegranate,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
