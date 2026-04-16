import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/icons/app_icons.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_state.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../auth/auth_provider.dart';
import '../../../groups/presentation/pages/join_group_page.dart';
import '../../../groups/presentation/pages/create_group_page.dart';
import '../../../groups/presentation/pages/group_detail_page.dart';
import '../../../groups/presentation/pages/accept_invite_page.dart';
import '../../../groups/group_provider.dart';

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> with RouteAware {
  final TextEditingController _searchController = TextEditingController();
  ModalRoute<dynamic>? _route;

  Future<void> _refreshData() async {
    if (!mounted) return;
    await context.read<GroupProvider>().fetchGroupsAndInvites();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshData());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    _refreshData();
  }

  @override
  void didPopNext() {
    _refreshData();
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    _searchController.dispose();
    super.dispose();
  }

  String get _query => _searchController.text.trim().toLowerCase();

  void _openCreateGroup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupPage()),
    ).then((val) {
      if (val == true) _refreshData();
    });
  }

  void _openJoinViaCode() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const JoinGroupPage()),
    ).then((val) {
      if (val == true) _refreshData();
    });
  }

  Widget _buildGreetingHeader(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final displayName = authProvider.user?.displayName ?? 'There';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hi, $displayName!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage and track your shared expenses',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _openCreateGroup,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFFC64A3C).withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC64A3C).withAlpha(40)),
                ),
                child: const Column(
                  children: [
                    Icon(AppIcons.add, color: Color(0xFFC64A3C)),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Create Group',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC64A3C),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: InkWell(
              onTap: _openJoinViaCode,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: const Color(0xFF1B1B1C).withAlpha(10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF1B1B1C).withAlpha(20)),
                ),
                child: const Column(
                  children: [
                    Icon(AppIcons.memberAdd, color: Colors.black87),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'Join via Code',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvitesHorizontalList(List<dynamic> invites) {
    if (invites.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
    return SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
            child: Text(
              'Pending Invites',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              itemCount: invites.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  child: _InviteCard(
                    invite: invites[index],
                    onJoin: (token) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AcceptInvitePage(initialToken: token),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCF9F8),
      bottomNavigationBar: const SizedBox.shrink(),
      body: SafeArea(
        child: Consumer<GroupProvider>(
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
              color: const Color(0xFFA53227),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: AppSpacing.md),
                        _buildGreetingHeader(context),
                        const SizedBox(height: AppSpacing.md),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                          child: AppSearchField(
                            controller: _searchController,
                            hintText: 'Search groups...',
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _buildQuickActions(),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                  _buildInvitesHorizontalList(invites),
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                      child: Text(
                        'Your Groups',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  if (provider.isLoading && groupsAll.isEmpty && invites.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator(color: Color(0xFFA53227))),
                    )
                  else if (groups.isEmpty)
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
                    SliverPadding(
                      padding: const EdgeInsets.only(bottom: 120),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final g = groups[index];
                            if (g is! Map<String, dynamic>) {
                              return const SizedBox.shrink();
                            }

                            final groupId = (g['_id'] ?? g['id'] ?? '').toString();
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
                    ),
                ],
              ),
            );
          },
        ),
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
    final description = (data['description'] ?? '').toString();
    final currency = (data['baseCurrency'] ?? data['currency'] ?? 'VND').toString().toUpperCase();
    final membersCount = _memberCount(data);
    final membersList = data['members'] as List? ?? [];

    final accent = _accentFromKey(scheme.primary, title);
    final accentBg = accent.withAlpha(28);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      if (description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          description,
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
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
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if (membersList.isNotEmpty)
                      SizedBox(
                        width: (membersList.length > 3 ? 3 : membersList.length) * 20.0 + 12.0,
                        height: 28,
                        child: Stack(
                          children: List.generate(
                            membersList.length > 3 ? 3 : membersList.length,
                            (index) {
                              final member = membersList[index];
                              final user = member['user'] as Map<String, dynamic>?;
                              final avatarUrl = user?['avatarUrl'] as String?;
                              final displayName = (user?['displayName'] ?? 'U').toString();
                              return Positioned(
                                left: index * 20.0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Colors.grey.shade300,
                                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                    child: avatarUrl == null
                                        ? Text(
                                            displayName[0].toUpperCase(),
                                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      '$membersCount members',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const Icon(AppIcons.chevronRight, size: 20, color: Colors.black45),
              ],
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

    return AppCard(
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
                    const SizedBox(height: 2),
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
            ],
          ),
          const SizedBox(height: AppSpacing.md),
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
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    foregroundColor: Colors.black87,
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: token.isEmpty ? null : () => onJoin(token),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFA53227),
                  ),
                  child: const Text('Join'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
