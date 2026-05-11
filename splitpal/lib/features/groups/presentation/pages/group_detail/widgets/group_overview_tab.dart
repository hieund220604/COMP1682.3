import 'package:flutter/material.dart';

import 'package:splitpal/core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/widgets/app_metric_tile.dart';
import 'package:splitpal/features/groups/presentation/pages/group_detail/widgets/group_debt_card.dart';
import 'package:splitpal/features/groups/presentation/pages/group_detail/widgets/group_spending_card.dart';
import 'package:splitpal/features/groups/presentation/pages/group_detail/widgets/group_upcoming_card.dart';
import 'package:splitpal/features/groups/presentation/pages/group_detail/widgets/members_preview_card.dart';
import 'package:splitpal/features/invoices/presentation/pages/bill_template_list_page.dart';

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
  final Future<void> Function(String memberId)? onTransferOwnership;
  final Future<void> Function(String memberId, String role)? onUpdateMemberRole;
  final void Function(int months)? onChangePeriod;

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
    this.onTransferOwnership,
    this.onUpdateMemberRole,
    this.onChangePeriod,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;



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

          Text('Quick actions', style: textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _QuickActionSquare(
                  icon: AppIcons.add,
                  label: 'Invoice',
                  isPrimary: true,
                  onPressed: onCreateInvoice,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickActionSquare(
                  icon: Icons.autorenew,
                  label: 'Recurring',
                  onPressed: isOwnerOrAdmin ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BillTemplateListPage(groupId: groupId),
                      ),
                    ).then((_) => onRefresh());
                  } : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickActionSquare(
                  icon: AppIcons.payments,
                  label: 'Request',
                  onPressed: onCreatePaymentRequest != null ? () => onCreatePaymentRequest!() : null,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickActionSquare(
                  icon: AppIcons.memberAdd,
                  label: 'Invite',
                  onPressed: onInvite,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickActionSquare(
                  icon: AppIcons.chat,
                  label: 'Chat',
                  onPressed: onOpenChat,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (dashboard != null) ...[
            // ── NEW: Spending Analytics ──
            if (dashboard!['spending'] != null)
              GroupSpendingCard(
                spending: dashboard!['spending'] as Map<String, dynamic>,
                currency: currency,
                onChangePeriod: onChangePeriod,
              ),
            if (dashboard!['spending'] != null)
              const SizedBox(height: AppSpacing.lg),
            // ── NEW: Settlement Health ──
            if (dashboard!['debts'] != null)
              GroupDebtCard(
                debts: dashboard!['debts'] as Map<String, dynamic>,
                currency: currency,
                groupId: groupId,
              ),
            if (dashboard!['debts'] != null)
              const SizedBox(height: AppSpacing.lg),
            // ── NEW: Upcoming Events ──
            if (dashboard!['upcoming'] != null)
              GroupUpcomingCard(
                upcoming: dashboard!['upcoming'] as Map<String, dynamic>,
                currency: currency,
              ),
            if (dashboard!['upcoming'] != null)
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

class _QuickActionSquare extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _QuickActionSquare({
    required this.icon,
    required this.label,
    this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final enabled = onPressed != null;

    final bgColor = isPrimary 
        ? scheme.primary 
        : scheme.surfaceContainerHighest.withOpacity(0.5);
    final fgColor = isPrimary 
        ? scheme.onPrimary 
        : scheme.onSurface;

    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadii.md),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: fgColor, size: 24),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: textTheme.labelSmall?.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

double _sd(dynamic v) {
  if (v == null) return 0.0;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0.0;
  if (v is Map) {
    final d = v['\$numberDecimal'] ?? v['numberDecimal'];
    if (d != null) return double.tryParse(d.toString()) ?? 0.0;
  }
  return 0.0;
}
