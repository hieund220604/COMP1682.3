import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/theme/theme_controller.dart';
import 'package:splitpal/features/auth/auth_provider.dart';
import '../../../auth/presentation/pages/setup_2fa_page.dart';
import '../../../auth/presentation/widgets/totp_verification_dialog.dart';
import 'package:splitpal/features/notifications/notification_provider.dart';
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
    final authProvider = context.read<AuthProvider>();
    final notificationProvider = context.read<NotificationProvider>();

    await Future.wait([
      authProvider.getCurrentUser(silent: true),
      notificationProvider.loadNotificationPreferences(),
    ]);
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
          _ProfileItem(
            icon: Icons.notifications,
            title: 'Notifications',
            trailing: const _NotificationPreferenceToggleItem(),
          ),
          _ProfileItem(
            icon: Icons.dark_mode,
            title: 'Dark Theme',
            trailing: const _ThemeModeToggleItem(),
          ),
          _ProfileItem(
            icon: Icons.list_alt,
            title: 'Show Onboarding on Login',
            trailing: _OnboardingToggleItem(),
          ),
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
                  ...sections.expand(
                    (s) => [
                      Text(
                        s.title.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _SettingsCard(items: s.items),
                      const SizedBox(height: 14),
                    ],
                  ),
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
        final authProvider = context.read<AuthProvider>();
        final messenger = ScaffoldMessenger.of(context);

        // Refresh user data
        await authProvider.getCurrentUser(silent: true);
        messenger.showSnackBar(
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
        await context.read<AuthProvider>().getCurrentUser(silent: true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Two-Factor Authentication disabled')),
          );
        }
      } else {
        final errMsg =
            context.read<AuthProvider>().errorMessage ??
            'Failed to disable 2FA';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errMsg)));
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
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'What is this about?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'How can we help?',
              ),
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
              if (subjectController.text.isEmpty ||
                  messageController.text.isEmpty) {
                return;
              }
              Navigator.pop(context); // Close dialog first or show loading

              // Show loading snackbar or indicator... simplifying here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sending message...')),
              );

              final success = await context.read<AuthProvider>().contactUs(
                subject: subjectController.text,
                message: messageController.text,
              );

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Message sent successfully!')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to send message')),
                  );
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
      padding: const EdgeInsets.fromLTRB(4, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 48), // balance the back button
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
        : const NetworkImage(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuDeRKKzK54qgIUcQmLhDNFm9iz3iKedfgpG5XJtx6M9mLfwAfHHXuKqMe2xw5nFQi60TkzfnwRzORGnSTF3Nm4BXQrH_cOYXtid4a5gsregQlOeX8anwVdDRMgL64oS_ellebq1pL6HqG-wrJ0esmwkZKwmOC3HILbQiFw_SbiJ03flJrrcB08OMKwcp7ssj1E30fZ2vuGRPYDD13BPKBH5XSJgRRQ8sRPY8o8N_yxmov82kvHVMbWVMfEeOXv2CjkBfJpeHw1o4rc',
          ); // fallback image

    return Column(
      children: [
        Stack(
          children: [
            Container(
              height: 108,
              width: 108,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.black.withAlpha((0.28 * 255).round())
                        : Colors.black12,
                    blurRadius: 8,
                  ),
                ],
                image: DecorationImage(fit: BoxFit.cover, image: imageProvider),
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
                  border: Border.all(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    width: 2,
                  ),
                ),
                child: Icon(
                  Icons.edit,
                  size: 16,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            if (user?.isPro == true) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade400,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
        border: Border.all(
          color: Theme.of(context).dividerColor.withAlpha((0.12 * 255).round()),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withAlpha((0.2 * 255).round())
                : Colors.black12,
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _SettingsRow(item: items[i]),
            if (i != items.length - 1)
              Divider(
                height: 1,
                color: Theme.of(context)
                    .dividerColor
                    .withAlpha((0.2 * 255).round()),
              ),
          ],
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
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withAlpha((0.08 * 255).round()),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item.icon,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            if (item.trailing != null) item.trailing!,
            if (item.trailingText != null)
              Text(
                item.trailingText!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            if (item.trailing == null)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingToggleItem extends StatefulWidget {
  const _OnboardingToggleItem();

  @override
  State<_OnboardingToggleItem> createState() => _OnboardingToggleItemState();
}

class _OnboardingToggleItemState extends State<_OnboardingToggleItem> {
  bool? _isEnabled;

  @override
  void initState() {
    super.initState();
    _loadToggleState();
  }

  Future<void> _loadToggleState() async {
    final authProvider = context.read<AuthProvider>();
    final enabled = await authProvider.getShowOnboardingOnLogin();
    if (mounted) {
      setState(() {
        _isEnabled = enabled;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isEnabled == null) {
      return _AppSwitch(
        value: false,
        loading: true,
        onChanged: null,
      );
    }

    return _AppSwitch(
      value: _isEnabled!,
      onChanged: (value) async {
        setState(() {
          _isEnabled = value;
        });
        final authProvider = context.read<AuthProvider>();
        final messenger = ScaffoldMessenger.of(context);
        await authProvider.setShowOnboardingOnLogin(value);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? 'Onboarding will show on next login'
                  : 'Onboarding disabled - access directly to home',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

class _ThemeModeToggleItem extends StatelessWidget {
  const _ThemeModeToggleItem();

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          themeController.themeModeLabel,
          style: TextStyle(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 8),
        _AppSwitch(
          value: themeController.isDarkThemeEnabled,
          onChanged: (value) async {
            final messenger = ScaffoldMessenger.of(context);
            await themeController.setDarkThemeEnabled(value);

            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  value
                      ? 'Dark theme enabled'
                      : 'Theme set to follow your system preference',
                ),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _NotificationPreferenceToggleItem extends StatefulWidget {
  const _NotificationPreferenceToggleItem();

  @override
  State<_NotificationPreferenceToggleItem> createState() =>
      _NotificationPreferenceToggleItemState();
}

class _NotificationPreferenceToggleItemState
    extends State<_NotificationPreferenceToggleItem> {
  @override
  Widget build(BuildContext context) {
    final notificationProvider = context.watch<NotificationProvider>();
    final authProvider = context.read<AuthProvider>();

    final isLoading = notificationProvider.isPreferencesLoading ||
        notificationProvider.pushNotificationsEnabled == null;
    final isUpdating = notificationProvider.isPreferencesUpdating;

    return _AppSwitch(
      value: notificationProvider.pushNotificationsEnabled ?? false,
      loading: isLoading,
      onChanged: (isLoading || isUpdating)
          ? null
          : (value) async {
              final messenger = ScaffoldMessenger.of(context);
              final theme = Theme.of(context);
              final success = await notificationProvider
                  .updateNotificationPreference(value);
              if (!mounted) return;

              if (success) {
                await authProvider.getCurrentUser(silent: true);
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      value
                          ? 'Push notifications enabled'
                          : 'Push notifications disabled',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } else {
                final error = notificationProvider.errorMessage ??
                    'Failed to update notifications';
                if (!mounted) return;
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(error),
                    backgroundColor: theme.colorScheme.error
                        .withAlpha((0.9 * 255).round()),
                  ),
                );
              }
            },
    );
  }
}

class _AppSwitch extends StatelessWidget {
  final bool value;
  final bool loading;
  final ValueChanged<bool>? onChanged;

  const _AppSwitch({
    required this.value,
    this.loading = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (loading) {
      return SizedBox(
        width: 38,
        height: 24,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: colorScheme.onPrimary,
      activeTrackColor: colorScheme.primary,
      inactiveThumbColor: colorScheme.outline,
      inactiveTrackColor: colorScheme.surfaceContainerHigh,
      trackOutlineColor: WidgetStatePropertyAll(
        colorScheme.outlineVariant.withAlpha((0.8 * 255).round()),
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _LogoutCard extends StatefulWidget {
  @override
  State<_LogoutCard> createState() => _LogoutCardState();
}

class _LogoutCardState extends State<_LogoutCard> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _isLoggingOut ? null : () => _handleLogout(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.surface,
            foregroundColor: colorScheme.primary,
            minimumSize: const Size.fromHeight(54),
            side: BorderSide(
              color: colorScheme.primary.withAlpha((0.25 * 255).round()),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          icon: _isLoggingOut
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          label: const Text(
            'Logout',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'SplitPal Version 2.4.0 (Build 392)',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    // Guard: prevent double-tap opening 2 dialogs
    if (_isLoggingOut) return;

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

    if (confirmed != true || !context.mounted) return;

    setState(() => _isLoggingOut = true);

    final auth = context.read<AuthProvider>();
    await auth.logout();

    if (!context.mounted) return;

    // Clear the entire navigation stack so no previously-pushed routes
    // (GroupDetail, InvoiceDetail, etc.) remain on top of the AuthPage
    // that Consumer will now render.
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil('/', (route) => false);
  }
}
