import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/di/injection_container.dart' as di;
import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_empty_state.dart';
import 'package:splitpal/features/auth/presentation/providers/auth_provider.dart';
import 'package:splitpal/features/chat/presentation/providers/chat_provider.dart';
import 'package:splitpal/features/chat/presentation/widgets/chat_view.dart';
import 'package:splitpal/features/groups/presentation/pages/invite_member_page.dart';
import 'package:splitpal/features/groups/presentation/providers/group_provider.dart';
import 'package:splitpal/features/invoices/presentation/pages/create_invoice_page.dart';
import 'package:splitpal/features/invoices/presentation/providers/invoice_provider.dart';
import 'package:splitpal/features/invoices/presentation/widgets/payment_request_section.dart';
import 'package:splitpal/features/subscriptions/presentation/widgets/create_subscription_sheet.dart';
import 'package:splitpal/features/subscriptions/presentation/widgets/subscription_list.dart';
import 'package:splitpal/core/network/dio_client.dart';
import 'package:splitpal/core/constants/api_constants.dart';

import 'widgets/group_header.dart';
import 'widgets/group_invoices_tab.dart';
import 'widgets/group_overview_tab.dart';

class GroupDetailPage extends StatefulWidget {
  static const routeName = '/group-detail';
  final String groupId;
  final String groupName;

  const GroupDetailPage({
    super.key,
    required this.groupId,
    required this.groupName,
  });

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  Map<String, dynamic>? _dashboard;
  final DioClient _dio = di.sl<DioClient>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final userId = context.read<AuthProvider>().user?.id;
      context.read<GroupProvider>().fetchGroupDetailsData(
            widget.groupId,
            currentUserId: userId,
          );
      context.read<InvoiceProvider>().loadInvoices(widget.groupId);
      context.read<InvoiceProvider>().loadMyBalance(widget.groupId);
      _fetchDashboard();
    });
  }

  Future<void> _refreshGroup() async {
    final userId = context.read<AuthProvider>().user?.id;
    await context.read<GroupProvider>().fetchGroupDetailsData(
          widget.groupId,
          currentUserId: userId,
        );
    await _fetchDashboard();
  }

  Future<void> _fetchDashboard() async {
    try {
      final response = await _dio.get(ApiConstants.dashboardGroup(widget.groupId));
      if (!mounted) return;
      setState(() {
        _dashboard = response.data['data'] as Map<String, dynamic>?;
      });
    } catch (_) {
      // swallow errors; overview tab still works without dashboard
    }
  }

  void _openInvite() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InviteMemberPage(groupId: widget.groupId),
      ),
    );
  }

  void _openCreateInvoice() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateInvoicePage(groupId: widget.groupId),
      ),
    ).then((_) {
      context.read<InvoiceProvider>().loadInvoices(widget.groupId);
    });
  }

  Future<void> _createPaymentRequest() async {
    final invoiceProvider = context.read<InvoiceProvider>();
    final ok = await invoiceProvider.createPaymentRequest(widget.groupId);

    if (!mounted) return;

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment request created')),
      );
      // Refresh payment-related sections.
      await Future.wait([
        invoiceProvider.loadPaymentRequests(widget.groupId),
        invoiceProvider.loadMyTransfers(widget.groupId),
        invoiceProvider.loadInvoices(widget.groupId),
      ]);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            invoiceProvider.errorMessage ?? 'Failed to create payment request',
          ),
        ),
      );
    }
  }

  void _openCreateSubscription() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => CreateSubscriptionSheet(initialGroupId: widget.groupId),
    );
  }

  void _openGroupChat() {
    final groupName =
        context.read<GroupProvider>().currentGroup?['name'] ?? widget.groupName;
    final currentUserId = context.read<AuthProvider>().user?.id;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) => di.sl<ChatProvider>(),
          child: Scaffold(
            appBar: AppBar(title: Text('$groupName Chat')),
            body: ChatView(
              groupId: widget.groupId,
              currentUserId: currentUserId,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _transferOwnership(String memberId) async {
    final groupProvider = context.read<GroupProvider>();
    try {
      await groupProvider.transferOwnership(widget.groupId, memberId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _updateMemberRole(String memberId, String role) async {
    final groupProvider = context.read<GroupProvider>();
    try {
      await groupProvider.updateMemberRole(widget.groupId, memberId, role);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupProvider = context.watch<GroupProvider>();
    final group = groupProvider.currentGroup;
    final members = groupProvider.currentGroupMembers;
    final balance = groupProvider.currentGroupBalance;

    final name = (group?['name'] ?? widget.groupName).toString();
    final currency =
        (group?['baseCurrency'] ?? group?['currency'] ?? 'VND').toString();

    final resolvedRole = (groupProvider.currentUserRole?.isNotEmpty ?? false)
        ? groupProvider.currentUserRole
        : _resolveRoleFromMembers(members);
    final isOwnerOrAdmin =
        resolvedRole == 'OWNER' || resolvedRole == 'ADMIN';

    if (groupProvider.isLoading && group == null) {
      return _GroupDetailLoadingScaffold(groupName: name);
    }

    if (groupProvider.error != null && group == null) {
      return Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                color: Theme.of(context).colorScheme.primary,
                icon: const Icon(AppIcons.back),
              ),
              title: Text(name),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: AppEmptyState(
                icon: AppIcons.groups,
                title: 'Could not load group',
                message: groupProvider.error,
                actionLabel: 'Retry',
                onAction: _refreshGroup,
              ),
            ),
          ],
        ),
      );
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar.large(
              leading: IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.pop(context),
                color: Theme.of(context).colorScheme.primary,
                icon: const Icon(AppIcons.back),
              ),
              title: Text(name),
              actions: [
                IconButton(
                  tooltip: 'Chat',
                  onPressed: _openGroupChat,
                  color: Theme.of(context).colorScheme.primary,
                  icon: const Icon(AppIcons.chat),
                ),
                if (isOwnerOrAdmin)
                  IconButton(
                    tooltip: 'Invite',
                    onPressed: _openInvite,
                    color: Theme.of(context).colorScheme.primary,
                    icon: const Icon(AppIcons.memberAdd),
                  ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.md,
                ),
                child: GroupHeader(
                  memberCount: members.length,
                  currency: currency,
                  role: resolvedRole,
                ),
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  tabs: const [
                    Tab(text: 'Overview', icon: Icon(AppIcons.overview)),
                    Tab(text: 'Invoices', icon: Icon(AppIcons.invoices)),
                    Tab(text: 'Payments', icon: Icon(AppIcons.payments)),
                    Tab(text: 'Subs', icon: Icon(AppIcons.subscriptions)),
                  ],
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              GroupOverviewTab(
                groupId: widget.groupId,
                groupName: name,
                members: members,
                balance: balance,
                currency: currency,
                role: resolvedRole,
                isOwnerOrAdmin: isOwnerOrAdmin,
                dashboard: _dashboard,
                onRefresh: _refreshGroup,
                onOpenChat: _openGroupChat,
                onInvite: isOwnerOrAdmin ? _openInvite : null,
                onCreateInvoice: isOwnerOrAdmin ? _openCreateInvoice : null,
                onCreatePaymentRequest:
                    isOwnerOrAdmin ? _createPaymentRequest : null,
                onCreateSubscription:
                    isOwnerOrAdmin ? _openCreateSubscription : null,
                onTransferOwnership: resolvedRole == 'OWNER' ? _transferOwnership : null,
                onUpdateMemberRole: isOwnerOrAdmin ? _updateMemberRole : null,
              ),
              GroupInvoicesTab(
                groupId: widget.groupId,
                isOwnerOrAdmin: isOwnerOrAdmin,
                onCreateInvoice: isOwnerOrAdmin ? _openCreateInvoice : null,
              ),
              ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: PaymentRequestSection(
                  groupId: widget.groupId,
                  groupName: name,
                  currency: currency,
                  isOwnerOrAdmin: isOwnerOrAdmin,
                  onCreatePaymentRequest:
                      isOwnerOrAdmin ? _createPaymentRequest : null,
                ),
              ),
              ColoredBox(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SubscriptionList(groupId: widget.groupId),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _resolveRoleFromMembers(List<dynamic> members) {
    final user = context.read<AuthProvider>().user;
    final userId = user?.id;
    final userEmail = user?.email;
    if (userId == null && userEmail == null) return null;

    for (final m in members) {
      if (m is! Map<String, dynamic>) continue;

      final role = m['role']?.toString();
      final userMap = m['user'];
      final memberUserId =
          (m['userId'] ?? (userMap is Map ? userMap['id'] : null))?.toString();
      final memberEmail =
          (userMap is Map ? userMap['email'] : m['email'])?.toString();

      final isMe =
          (userId != null && memberUserId == userId) ||
          (userEmail != null && memberEmail == userEmail);
      if (!isMe) continue;

      return role?.toUpperCase();
    }

    return null;
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withOpacity(0.6)),
        ),
      ),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}

class _GroupDetailLoadingScaffold extends StatelessWidget {
  final String groupName;

  const _GroupDetailLoadingScaffold({required this.groupName});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.large(
            leading: IconButton(
              tooltip: 'Back',
              onPressed: () => Navigator.pop(context),
              color: Theme.of(context).colorScheme.primary,
              icon: const Icon(AppIcons.back),
            ),
            title: Text(groupName),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _SkeletonBox(height: 82, color: scheme.surfaceContainerLowest),
                  const SizedBox(height: AppSpacing.md),
                  _SkeletonBox(
                    height: 160,
                    color: scheme.surfaceContainerLowest,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SkeletonBox(height: 220, color: scheme.surfaceContainerLowest),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final Color color;

  const _SkeletonBox({
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
      ),
    );
  }
}
