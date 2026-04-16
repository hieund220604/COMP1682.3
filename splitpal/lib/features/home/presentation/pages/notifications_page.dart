import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:splitpal/core/navigation/app_route_observer.dart';
import 'package:splitpal/models/notification.dart';
import 'package:splitpal/features/notifications/notification_provider.dart';
import '../../../groups/presentation/pages/group_detail_page.dart';
import '../../../groups/presentation/pages/groups_page.dart';
import '../../../groups/presentation/pages/accept_invite_page.dart';
import '../../../invoices/presentation/pages/my_invoices_page.dart';
import 'transaction_history_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> with RouteAware {
  ModalRoute<dynamic>? _route;

  Future<void> _refreshData() async {
    await context.read<NotificationProvider>().fetchNotifications();
    if (!mounted) return;
    await context.read<NotificationProvider>().fetchUnreadCount();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<NotificationProvider>(
          builder: (context, provider, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Notifications'),
                if (provider.unreadCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${provider.unreadCount}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              final provider = context.read<NotificationProvider>();
              if (value == 'mark_all_read') {
                provider.markAllAsRead();
              } else if (value == 'delete_read') {
                provider.deleteAllRead().then((count) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$count notification(s) deleted')),
                    );
                  }
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'mark_all_read',
                child: Text('Mark all as read'),
              ),
              const PopupMenuItem(
                value: 'delete_read',
                child: Text('Delete read notifications'),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<NotificationProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.status == NotificationStatus.error) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(provider.errorMessage ?? 'An error occurred'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchNotifications(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              await provider.fetchNotifications();
              await provider.fetchUnreadCount();
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemBuilder: (_, i) => _NotificationTile(
                notification: provider.notifications[i],
                onTap: () => _handleNotificationTap(provider.notifications[i]),
                onDelete: () {
                  provider.deleteNotification(provider.notifications[i].id);
                },
              ),
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemCount: provider.notifications.length,
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleNotificationTap(AppNotification notification) async {
    final provider = context.read<NotificationProvider>();

    if (!notification.read) {
      await provider.markAsRead(notification.id);
    }

    if (!mounted) return;

    _navigateForNotification(notification);
  }

  void _navigateForNotification(AppNotification notification) {
    final data = notification.data ?? const {};

    // Balance-related notifications -> transaction history
    if (_isBalanceNotification(notification.type)) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const TransactionHistoryPage()),
      );
      return;
    }

    // Invitation notifications -> invite accept flow first
    if (notification.type == NotificationType.inviteReceived) {
      final inviteToken = data['inviteToken'] as String?;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AcceptInvitePage(initialToken: inviteToken),
        ),
      );
      return;
    }

    // Payment request cancelled -> invoices
    if (notification.type == NotificationType.paymentRequestCancelled) {
      Navigator.of(context).pushNamed(MyInvoicesPage.routeName);
      return;
    }

    // Group-related notifications -> group detail/overview
    if (_isGroupNotification(notification.type)) {
      final groupId = data['groupId'] as String?;
      final groupName = data['groupName'] as String? ?? 'Group';
      if (groupId != null && groupId.isNotEmpty) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => GroupDetailPage(
              groupId: groupId,
              groupName: groupName,
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GroupsPage()),
        );
      }
      return;
    }

    // Other types: no-op for now.
  }

  bool _isBalanceNotification(NotificationType type) {
    switch (type) {
      case NotificationType.balanceUpdated:
      case NotificationType.paymentRefunded:
      case NotificationType.paymentReceived:
        return true;
      default:
        return false;
    }
  }

  bool _isGroupNotification(NotificationType type) {
    switch (type) {
      case NotificationType.expenseCreated:
      case NotificationType.expenseUpdated:
      case NotificationType.invoiceCreated:
      case NotificationType.settlementCreated:
      case NotificationType.groupJoined:
        return true;
      default:
        return false;
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.expenseCreated:
      case NotificationType.expenseUpdated:
        return Icons.receipt_long;
      case NotificationType.invoiceCreated:
        return Icons.description;
      case NotificationType.settlementCreated:
        return Icons.account_balance;
      case NotificationType.paymentReceived:
        return Icons.payments;
      case NotificationType.inviteReceived:
        return Icons.mail;
      case NotificationType.groupJoined:
        return Icons.group_add;
      case NotificationType.balanceUpdated:
        return Icons.account_balance_wallet;
      case NotificationType.paymentRequestCancelled:
        return Icons.cancel_presentation;
      case NotificationType.paymentRefunded:
        return Icons.replay_circle_filled;
    }
  }

  Color _getColorForType(NotificationType type) {
    switch (type) {
      case NotificationType.expenseCreated:
      case NotificationType.expenseUpdated:
        return Colors.orange;
      case NotificationType.invoiceCreated:
        return Colors.blue;
      case NotificationType.settlementCreated:
        return Colors.purple;
      case NotificationType.paymentReceived:
        return Colors.green;
      case NotificationType.inviteReceived:
        return Colors.pink;
      case NotificationType.groupJoined:
        return Colors.teal;
      case NotificationType.balanceUpdated:
        return Colors.indigo;
      case NotificationType.paymentRequestCancelled:
        return Colors.deepOrange;
      case NotificationType.paymentRefunded:
        return Colors.green;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final iconColor = _getColorForType(notification.type);

    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notification.read
                ? Theme.of(context).colorScheme.surface
                : colorScheme.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notification.read
                  ? Theme.of(context).dividerColor.withOpacity(0.12)
                  : colorScheme.primary.withOpacity(0.2),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getIconForType(notification.type),
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: notification.read
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                          ),
                        ),
                        if (!notification.read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(notification.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
