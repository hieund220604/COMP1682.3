import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/features/groups/group_provider.dart';

class InviteMemberPage extends StatefulWidget {
  final String groupId;

  const InviteMemberPage({
    super.key,
    required this.groupId,
  });

  @override
  State<InviteMemberPage> createState() => _InviteMemberPageState();
}

class _InviteMemberPageState extends State<InviteMemberPage> {
  final TextEditingController _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendInvite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isLoading = true);
    final ok = await context.read<GroupProvider>().inviteMember(
          widget.groupId,
          email,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invitation sent')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<GroupProvider>().error ?? 'Failed to invite'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(AppIcons.back),
        ),
        title: const Text('Invite member'),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Invite someone by email to join this group.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _isLoading ? null : _sendInvite(),
                decoration: const InputDecoration(
                  hintText: 'friend@example.com',
                  prefixIcon: Icon(AppIcons.mail),
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isLoading ? null : _sendInvite,
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send invite'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

