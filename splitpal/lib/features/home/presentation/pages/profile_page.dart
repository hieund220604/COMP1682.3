import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../auth/presentation/pages/setup_2fa_page.dart';
import '../../../auth/presentation/widgets/totp_verification_dialog.dart';
import 'edit_profile_page.dart';
import 'change_password_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with RouteAware {
  ModalRoute<dynamic>? _route;

  Future<void> _refreshData() async {
    await context.read<AuthProvider>().getCurrentUser();
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
    final user = context.watch<AuthProvider>().user;
    final is2FAEnabled = user?.twoFactorEnabled ?? false;

    final sections = [
      _ProfileSection(
        title: 'Account Settings',
        items: [
          _ProfileItem(
            icon: Icons.person,
            title: 'Edit Profile',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EditProfilePage()),
            ),
          ),
          _ProfileItem(
            icon: Icons.lock,
            title: 'Change Password',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
            ),
          ),
          _ProfileItem(
            icon: Icons.security,
            title: 'Two-Factor Auth',
            trailingText: is2FAEnabled ? 'Enabled' : 'Disabled',
            onTap: () => _handle2FATap(is2FAEnabled),
          ),
          // Privacy Settings Removed
        ],
      ),
      _ProfileSection(
        title: 'App Preferences',
        items: [
          _ProfileItem(icon: Icons.notifications, title: 'Notifications', trailing: _SwitchMock(on: true)),
          _ProfileItem(icon: Icons.palette, title: 'Theme', trailingText: 'Light'),
        ],
      ),
      _ProfileSection(
        title: 'Support',
        items: [
          // Help Center Removed
          _ProfileItem(
            icon: Icons.mail,
            title: 'Contact Us',
            onTap: () => _showContactUsDialog(context),
          ),
          // Rate App Removed
        ],
      ),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
                children: [
                  const _AvatarBlock(),
                  const SizedBox(height: 12),
                  ...sections.expand((s) => [
                        Text(
                          s.title.toUpperCase(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey,
                              ),
                        ),
                        const SizedBox(height: 6),
                        _SettingsCard(items: s.items),
                        const SizedBox(height: 14),
                      ]),
                  _LogoutCard(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const SizedBox.shrink(),
    );
  }

  Future<void> _handle2FATap(bool isEnabled) async {
    if (!isEnabled) {
      // Navigate to setup page
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const Setup2FAPage()),
      );
      if (result == true && mounted) {
        // Refresh user data
        await context.read<AuthProvider>().getCurrentUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Two-Factor Authentication enabled!')),
        );
      }
    } else {
      // Disable 2FA
      _handleDisable2FA();
    }
  }

  Future<void> _handleDisable2FA() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable 2FA'),
        content: const Text(
          'Are you sure you want to disable Two-Factor Authentication? '
          'This will make your account less secure.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disable', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final code = await TotpVerificationDialog.show(context);
    if (code == null || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await context.read<AuthProvider>().disable2FA(token: code);

    if (mounted) {
      Navigator.pop(context); // Close loading
      if (success) {
        await context.read<AuthProvider>().getCurrentUser();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Two-Factor Authentication disabled')),
          );
        }
      } else {
        final errMsg = context.read<AuthProvider>().errorMessage ?? 'Failed to disable 2FA';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errMsg)),
        );
      }
    }
  }

  void _showContactUsDialog(BuildContext context) {
    final subjectController = TextEditingController();
    final messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Us'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(labelText: 'Subject', hintText: 'What is this about?'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(labelText: 'Message', hintText: 'How can we help?'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
               if (subjectController.text.isEmpty || messageController.text.isEmpty) {
                 return;
               }
               Navigator.pop(context); // Close dialog first or show loading
               
               // Show loading snackbar or indicator... simplifying here
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sending message...')));
               
               final success = await context.read<AuthProvider>().contactUs(
                 subject: subjectController.text,
                 message: messageController.text,
               );
               
               if (context.mounted) {
                 if (success) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Message sent successfully!')));
                 } else {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to send message')));
                 }
               }
            },
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          const SizedBox(width: 42),
          Expanded(
            child: Text(
              'Profile',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock();

  @override
  Widget build(BuildContext context) {
    // Watch AuthProvider for updates
    final user = context.watch<AuthProvider>().user;
    final displayName = user?.displayName ?? 'User';
    final email = user?.email ?? 'user@example.com';
    final avatarUrl = user?.avatarUrl; 
    // Default avatar if none provided
    final imageProvider = (avatarUrl != null && avatarUrl.isNotEmpty) 
        ? NetworkImage(avatarUrl) 
        : const NetworkImage('https://lh3.googleusercontent.com/aida-public/AB6AXuDeRKKzK54qgIUcQmLhDNFm9iz3iKedfgpG5XJtx6M9mLfwAfHHXuKqMe2xw5nFQi60TkzfnwRzORGnSTF3Nm4BXQrH_cOYXtid4a5gsregQlOeX8anwVdDRMgL64oS_ellebq1pL6HqG-wrJ0esmwkZKwmOC3HILbQiFw_SbiJ03flJrrcB08OMKwcp7ssj1E30fZ2vuGRPYDD13BPKBH5XSJgRRQ8sRPY8o8N_yxmov82kvHVMbWVMfEeOXv2CjkBfJpeHw1o4rc'); // fallback image

    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 108,
              width: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
                image: DecorationImage(
                  fit: BoxFit.cover,
                  image: imageProvider,
                ),
              ),
            ),
            Positioned(
              right: 4,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                ),
                child: const Icon(Icons.edit, size: 16, color: Colors.white),
              ),
            )
          ],
        ),
        const SizedBox(height: 10),
        Text(displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(email, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 14),
      ],
    );
  }
}

class _ProfileSection {
  final String title;
  final List<_ProfileItem> items;

  _ProfileSection({required this.title, required this.items});
}

class _ProfileItem {
  final IconData icon;
  final String title;
  final String? trailingText;
  final Widget? trailing;
  final VoidCallback? onTap;

  _ProfileItem({
    required this.icon,
    required this.title,
    this.trailingText,
    this.trailing,
    this.onTap,
  });
}

class _SettingsCard extends StatelessWidget {
  final List<_ProfileItem> items;

  const _SettingsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.12)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _SettingsRow(item: items[i]),
            if (i != items.length - 1)
              Divider(height: 1, color: Theme.of(context).dividerColor.withOpacity(0.2)),
          ]
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final _ProfileItem item;

  const _SettingsRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              height: 42,
              width: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            if (item.trailing != null) item.trailing!,
            if (item.trailingText != null)
              Text(
                item.trailingText!,
                style: const TextStyle(color: Colors.grey),
              ),
            if (item.trailing == null)
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _SwitchMock extends StatelessWidget {
  final bool on;

  const _SwitchMock({required this.on});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 46,
      height: 26,
      decoration: BoxDecoration(
        color: on ? colorScheme.primary : Colors.grey.shade400,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: on ? Alignment.centerRight : Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _handleLogout(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Theme.of(context).colorScheme.primary,
            minimumSize: const Size.fromHeight(54),
            side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.25)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          icon: const Icon(Icons.logout),
          label: const Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'SplitPal Version 2.4.0 (Build 392)',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        )
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Perform logout
      await context.read<AuthProvider>().logout();

      if (context.mounted) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Navigate to auth page and clear stack
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }
    }
  }
}
