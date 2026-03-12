import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../groups/presentation/pages/accept_invite_page.dart';
import '../../../groups/presentation/pages/create_group_page.dart';
import '../../../groups/presentation/pages/group_detail_page.dart';
import '../../../groups/presentation/providers/group_provider.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final TextEditingController _searchController = TextEditingController();
  bool _showInvites = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().fetchGroupsAndInvites();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _query => _searchController.text.trim().toLowerCase();

  void _openCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupPage()),
    );
  }

  void _openJoinViaCode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AcceptInvitePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 60),
        child: FloatingActionButton.extended(
          onPressed: _openCreateGroup,
          icon: const Icon(AppIcons.add),
          label: const Text('Create group'),
        ),
      ),
      bottomNavigationBar: const SizedBox.shrink(),
      body: Consumer<GroupProvider>(
        builder: (context, provider, child) {
          final invites = provider.invites;
          final groupsAll = provider.groups;

          final groups = _query.isEmpty
              ? groupsAll
              : groupsAll
                  .where((g) {
                    if (g is! Map<String, dynamic>) return false;
                    final name = (g['name'] ?? '').toString().toLowerCase();
                    return name.contains(_query);
                  })
                  .toList(growable: false);

          return RefreshIndicator(
            onRefresh: provider.fetchGroupsAndInvites,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar.large(
                  title: const Text('Groups'),
                  actions: [
                    IconButton(
                      tooltip: 'Join via code',
                      onPressed: _openJoinViaCode,
                      icon: const Icon(AppIcons.memberAdd),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.sm),
                      AppSearchField(
                        controller: _searchController,
                        hintText: 'Search groups...',
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                  ),
                ),
                if (provider.isLoading && groupsAll.isEmpty && invites.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  if (invites.isNotEmpty && _showInvites) ...[
                    SliverToBoxAdapter(
                      child: AppSectionHeader(
                        title: 'Invitations',
                        subtitle: '${invites.length} pending',
                        trailing: TextButton(
                          onPressed: () => setState(() => _showInvites = false),
                          child: const Text('Hide'),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _InviteCard(
                          invite: invites[index],
                          onJoin: (token) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AcceptInvitePage(initialToken: token),
                              ),
                            );
                          },
                        ),
                        childCount: invites.length,
                      ),
                    ),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.md),
                    ),
                  ],
                  SliverToBoxAdapter(
                    child: AppSectionHeader(
                      title: 'Your groups',
                      subtitle:
                          groups.isEmpty ? null : '${groups.length} groups',
                      trailing: TextButton(
                        onPressed: _openCreateGroup,
                        child: const Text('Create'),
                      ),
                    ),
                  ),
                  if (groups.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: AppEmptyState(
                        icon: AppIcons.groups,
                        title: _query.isEmpty ? 'No groups yet' : 'No results',
                        message: _query.isEmpty
                            ? 'Create a group to start tracking shared expenses.'
                            : 'Try a different keyword.',
                        actionLabel: _query.isEmpty ? 'Create group' : null,
                        onAction: _query.isEmpty ? _openCreateGroup : null,
                      ),
                    )
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final g = groups[index];
                          if (g is! Map<String, dynamic>) {
                            return const SizedBox.shrink();
                          }

                          final groupId =
                              (g['_id'] ?? g['id'] ?? '').toString();
                          final groupName = (g['name'] ?? 'Group').toString();

                          return _GroupCard(
                            data: g,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => GroupDetailPage(
                                    groupId: groupId,
                                    groupName: groupName,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                        childCount: groups.length,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        130,
                      ),
                      child: _JoinViaCodeCard(onTap: _openJoinViaCode),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

Color _accentFromKey(Color base, String key) {
  final hsl = HSLColor.fromColor(base);
  final bucket = key.hashCode.abs() % 7;
  final shift = 10.0 + (bucket * 14.0);
  return hsl.withHue((hsl.hue + shift) % 360).toColor();
}

int _memberCount(Map<String, dynamic> data) {
  final raw = data['memberCount'];
  if (raw is int) return raw;
  final members = data['members'];
  if (members is List) return members.length;
  return 0;
}

class _GroupCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  const _GroupCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final title = (data['name'] ?? 'Unnamed group').toString();
    final currency = (data['baseCurrency'] ?? data['currency'] ?? 'VND')
        .toString()
        .toUpperCase();
    final membersCount = _memberCount(data);

    final accent = _accentFromKey(scheme.primary, title);
    final accentBg = accent.withAlpha(28);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(AppRadii.md),
                border: Border.all(color: accent.withAlpha(60)),
              ),
              child: Icon(AppIcons.groups, color: accent),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$membersCount members',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Text(
                currency,
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  final dynamic invite;
  final ValueChanged<String> onJoin;

  const _InviteCard({
    required this.invite,
    required this.onJoin,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final groupName = (invite?['groupName'] ?? 'Unknown group').toString();
    final inviter = (invite?['invitedByName'] ?? 'Someone').toString();
    final token = (invite?['token'] ?? '').toString();
    final role = (invite?['role'] ?? 'USER').toString().toUpperCase();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(22),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: scheme.primary.withAlpha(50)),
                  ),
                  child: Icon(AppIcons.mail, color: scheme.primary),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        groupName,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Invited by $inviter',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(color: scheme.primary.withAlpha(40)),
                  ),
                  child: Text(
                    role,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Decline is not available yet'),
                        ),
                      );
                    },
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: token.isEmpty ? null : () => onJoin(token),
                    child: const Text('Join'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinViaCodeCard extends StatelessWidget {
  final VoidCallback onTap;

  const _JoinViaCodeCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      color: scheme.primary.withAlpha(14),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: scheme.primary.withAlpha(50)),
            ),
            child: Icon(AppIcons.memberAdd, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Join via code',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Paste an invitation token to join a group.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(AppIcons.chevronRight, color: scheme.primary),
        ],
      ),
    );
  }
}
