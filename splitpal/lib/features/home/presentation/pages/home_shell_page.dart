import 'package:flutter/material.dart';

import '../../../../core/icons/app_icons.dart';
import 'dashboard_page.dart';
import 'subscriptions_page.dart';
import 'groups_page.dart';
import 'notifications_page.dart';
import 'profile_page.dart';

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

  late final List<Widget> _pages = [
    const DashboardPage(),
    const SubscriptionsPage(),
    const GroupsPage(),
    const NotificationsPage(),
    const ProfilePage(),
  ];

  void _onTap(int i) {
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<SwitchTabNotification>(
      onNotification: (notification) {
        _onTap(notification.newIndex);
        return true;
      },
      child: Scaffold(
        body: _pages[_index],
        bottomNavigationBar: _BottomNavBar(
          current: _index,
          onTap: _onTap,
        ),
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
          icon: Icon(AppIcons.notifications),
          label: 'Activity',
        ),
        NavigationDestination(
          icon: Icon(AppIcons.settings),
          label: 'Settings',
        ),
      ],
    );
  }
}
