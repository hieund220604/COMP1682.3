import 'package:flutter/material.dart';

import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_card.dart';

class MembersPreviewCard extends StatelessWidget {
  final List<dynamic> members;
  final int previewCount;
  final VoidCallback? onViewAll;
  final String? currentUserRole;
  final Future<void> Function(String memberId)? onTransferOwnership;
  final Future<void> Function(String memberId, String role)? onUpdateMemberRole;

  const MembersPreviewCard({
    super.key,
    required this.members,
    this.previewCount = 5,
    this.onViewAll,
    this.currentUserRole,
    this.onTransferOwnership,
    this.onUpdateMemberRole,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final canViewAll = onViewAll != null && members.length > previewCount;
    final preview = members.take(previewCount).toList(growable: false);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Members', style: textTheme.titleSmall),
              const Spacer(),
              if (canViewAll)
                TextButton(
                  onPressed: onViewAll,
                  child: const Text('View all'),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (members.isEmpty)
            Text(
              'No members yet.',
              style: textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            )
          else
            ...preview.map((m) => _MemberRow(
              member: m,
              currentUserRole: currentUserRole,
              onTransferOwnership: onTransferOwnership,
              onUpdateMemberRole: onUpdateMemberRole,
            )),
        ],
      ),
    );
  }
}

class MembersBottomSheet extends StatelessWidget {
  final List<dynamic> members;
  final String? currentUserRole;
  final Future<void> Function(String memberId)? onTransferOwnership;
  final Future<void> Function(String memberId, String role)? onUpdateMemberRole;

  const MembersBottomSheet({
    super.key,
    required this.members,
    this.currentUserRole,
    this.onTransferOwnership,
    this.onUpdateMemberRole,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SafeArea(
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        builder: (context, controller) {
          return Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadii.lg),
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'All members',
                          style: textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(AppIcons.close),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.6)),
                Expanded(
                  child: ListView.separated(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    itemCount: members.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      return AppCard(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: _MemberRow(
                          member: members[index],
                          currentUserRole: currentUserRole,
                          onTransferOwnership: onTransferOwnership,
                          onUpdateMemberRole: onUpdateMemberRole,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MemberRow extends StatefulWidget {
  final dynamic member;
  final String? currentUserRole;
  final Future<void> Function(String memberId)? onTransferOwnership;
  final Future<void> Function(String memberId, String role)? onUpdateMemberRole;

  const _MemberRow({
    required this.member,
    this.currentUserRole,
    this.onTransferOwnership,
    this.onUpdateMemberRole,
  });

  @override
  State<_MemberRow> createState() => _MemberRowState();
}

class _MemberRowState extends State<_MemberRow> {
  bool _isLoading = false;

  Future<void> _showRoleOptions(BuildContext context) async {
    final role = _memberRole(widget.member);
    final memberId = widget.member['_id'] ?? widget.member['id'];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage ${_memberName(widget.member)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (widget.currentUserRole == 'OWNER' && role != 'Owner') ...[
                ListTile(
                  title: const Text('Transfer Ownership'),
                  subtitle: const Text('Make this member the group owner'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _transferOwnership(context, memberId);
                  },
                ),
                const Divider(),
              ],
              if ((widget.currentUserRole == 'OWNER' || widget.currentUserRole == 'ADMIN') &&
                  role == 'Member') ...[
                ListTile(
                  title: const Text('Grant Admin'),
                  subtitle: const Text('Promote to admin'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateRole(context, memberId, 'ADMIN');
                  },
                ),
                const Divider(),
              ],
              if (widget.currentUserRole == 'OWNER' && role == 'Admin') ...[
                ListTile(
                  title: const Text('Demote to Member'),
                  subtitle: const Text('Remove admin privileges'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _updateRole(context, memberId, 'USER');
                  },
                ),
                const Divider(),
              ],
              ListTile(
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _transferOwnership(BuildContext context, String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer Ownership'),
        content: Text(
          'Transfer group ownership to ${_memberName(widget.member)}? You will become an admin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Transfer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await widget.onTransferOwnership?.call(memberId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ownership transferred successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateRole(BuildContext context, String memberId, String newRole) async {
    setState(() => _isLoading = true);
    try {
      await widget.onUpdateMemberRole?.call(memberId, newRole);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member role updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final name = _memberName(widget.member);
    final email = _memberEmail(widget.member);
    final role = _memberRole(widget.member);
    final avatarUrl = _memberAvatarUrl(widget.member);
    final canManage = widget.currentUserRole == 'OWNER' || 
                     widget.currentUserRole == 'ADMIN';

    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: scheme.surfaceContainerHighest,
          backgroundImage: avatarUrl == null ? null : NetworkImage(avatarUrl),
          child: avatarUrl == null
              ? Icon(AppIcons.person, color: scheme.onSurfaceVariant)
              : null,
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (email != null && email.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  email,
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        if (role != null) ...[
          Container(
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
              role,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.pomegranate,
              ),
            ),
          ),
          if (canManage && role != 'Owner') ...[
            const SizedBox(width: AppSpacing.md),
            if (_isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(AppIcons.more),
                onPressed: () => _showRoleOptions(context),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: EdgeInsets.zero,
                iconSize: 20,
              ),
          ],
        ],
      ],
    );
  }
}

Map<String, dynamic>? _memberUser(dynamic member) {
  if (member is! Map<String, dynamic>) return null;
  final user = member['user'];
  if (user is Map<String, dynamic>) return user;
  return null;
}

String _memberName(dynamic member) {
  if (member is! Map<String, dynamic>) return 'Unknown';
  final user = _memberUser(member);
  final displayName = (user?['displayName'] ?? user?['name'] ?? member['displayName'])
      ?.toString()
      .trim();
  if (displayName != null && displayName.isNotEmpty) return displayName;
  final email = _memberEmail(member);
  if (email != null && email.isNotEmpty) return email;
  return 'Unknown';
}

String? _memberEmail(dynamic member) {
  if (member is! Map<String, dynamic>) return null;
  final user = _memberUser(member);
  return (user?['email'] ?? member['email'])?.toString();
}

String? _memberAvatarUrl(dynamic member) {
  if (member is! Map<String, dynamic>) return null;
  final user = _memberUser(member);
  return (user?['avatarUrl'] ?? member['avatarUrl'])?.toString();
}

String? _memberRole(dynamic member) {
  if (member is! Map<String, dynamic>) return null;
  final raw = member['role']?.toString().toUpperCase();
  switch (raw) {
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

