import 'package:flutter/material.dart';

import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_card.dart';

class GroupHeader extends StatelessWidget {
  final int memberCount;
  final String currency;
  final String? role;

  const GroupHeader({
    super.key,
    required this.memberCount,
    required this.currency,
    this.role,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final roleText = _roleLabel(role);

    return AppCard(
      color: scheme.surface,
      elevation: 0,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: scheme.primary.withAlpha(60)),
            ),
            child: Icon(AppIcons.groups, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$memberCount members',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Base currency: ${currency.toUpperCase()}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (roleText != null) ...[
            const SizedBox(width: AppSpacing.md),
            _RoleChip(label: roleText),
          ],
        ],
      ),
    );
  }
}

String? _roleLabel(String? raw) {
  final v = raw?.toUpperCase();
  switch (v) {
    case 'OWNER':
      return 'Owner';
    case 'ADMIN':
      return 'Admin';
    case 'MEMBER':
    case 'USER':
      return 'Member';
    case null:
      return null;
    default:
      return raw;
  }
}

class _RoleChip extends StatelessWidget {
  final String label;

  const _RoleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: scheme.primary.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
