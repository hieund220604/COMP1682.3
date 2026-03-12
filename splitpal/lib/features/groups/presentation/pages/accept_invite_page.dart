import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import '../providers/group_provider.dart';

class AcceptInvitePage extends StatefulWidget {
  static const routeName = '/accept-invite';
  final String? initialToken;

  const AcceptInvitePage({super.key, this.initialToken});

  @override
  State<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends State<AcceptInvitePage> {
  late final TextEditingController _tokenController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tokenController = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() => _isLoading = true);
    final ok = await context.read<GroupProvider>().joinGroup(token);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (ok) {
      Navigator.popUntil(context, (route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined group successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.read<GroupProvider>().error ?? 'Failed to join group'),
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
        title: const Text('Join group'),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: scheme.primary.withAlpha(50)),
                  ),
                  child: Icon(AppIcons.key, color: scheme.primary, size: 34),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Enter invitation token',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Paste the token from your invitation link to join the group.',
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: _tokenController,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _isLoading ? null : _accept(),
                decoration: const InputDecoration(
                  hintText: 'Paste token here...',
                  prefixIcon: Icon(AppIcons.key),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(AppIcons.info, size: 16, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'If you received an email invite, the token is inside the link.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              SizedBox(
                height: 54,
                child: FilledButton(
                  onPressed: _isLoading ? null : _accept,
                  child: _isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text('Join group'),
                            SizedBox(width: AppSpacing.sm),
                            Icon(AppIcons.arrowForward, size: 18),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

