import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/icons/app_icons.dart';
import 'package:splitpal/ui/savings/savings_tab.dart';
import 'package:splitpal/features/notifications/notification_provider.dart';
import 'dashboard_page.dart';
import 'subscriptions_page.dart';
import 'groups_page.dart';
import 'profile_page.dart';
import '../../../../features/receipts/presentation/pages/budget_page.dart';

/// Notification to switch the home tab.
class SwitchTabNotification extends Notification {
  final int newIndex;
  SwitchTabNotification(this.newIndex);
}

/// Root container with bottom navigation for the main app.
class HomeShellPage extends StatefulWidget {
  static const routeName = '/home';

  const HomeShellPage({super.key});

  @override
  State<HomeShellPage> createState() => _HomeShellPageState();
}

class _HomeShellPageState extends State<HomeShellPage> {
  int _index = 0;
  final List<int> _tabRefreshTokens = List<int>.filled(5, 0);

  @override
  void initState() {
    super.initState();
    // Load unread notifications count once the widget is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().fetchUnreadCount();
    });
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return DashboardPage(key: ValueKey('dashboard-${_tabRefreshTokens[0]}'));
      case 1:
        return SubscriptionsPage(key: ValueKey('subscriptions-${_tabRefreshTokens[1]}'));
      case 2:
        return GroupsPage(key: ValueKey('groups-${_tabRefreshTokens[2]}'));
      case 3:
        return SavingsTab(key: ValueKey('savings-${_tabRefreshTokens[3]}'));
      default:
        return BudgetPage(key: ValueKey('budget-${_tabRefreshTokens[4]}'));
    }
  }

  void _onTap(int i) {
    setState(() {
      _index = i;
      _tabRefreshTokens[i] += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SwitchTabNotification>(
      onNotification: (notification) {
        _onTap(notification.newIndex);
        return true;
      },
      child: Scaffold(
        body: _buildPage(_index),
        bottomNavigationBar: _BottomNavBar(current: _index, onTap: _onTap),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;

  const _BottomNavBar({
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, notificationProvider, _) {
        final unread = notificationProvider.unreadCount;

        return NavigationBar(
          selectedIndex: current,
          onDestinationSelected: onTap,
          destinations: const [
            NavigationDestination(
              icon: Icon(AppIcons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.subscriptions),
              label: 'Subs',
            ),
            NavigationDestination(
              icon: Icon(AppIcons.groups),
              label: 'Groups',
            ),
            NavigationDestination(
              icon: Icon(Icons.savings),
              label: 'Savings',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Budget',
            ),
          ],
        );
      },
    );
  }
}
