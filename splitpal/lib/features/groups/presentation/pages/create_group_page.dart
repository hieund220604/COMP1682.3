import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import '../providers/group_provider.dart';

class CreateGroupPage extends StatefulWidget {
  static const routeName = '/create-group';

  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

  String _selectedCurrency = 'VND';

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final provider = context.read<GroupProvider>();
    final success = await provider.createGroup(
      _nameController.text.trim(),
      _selectedCurrency,
    );

    if (!mounted) return;

    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group created successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to create group'),
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
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
          icon: const Icon(AppIcons.close),
        ),
        title: const Text('Create group'),
      ),
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.pagePadding,
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      Text('Basic info', style: textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.lg),
                      _Label(text: 'Group name', requiredField: true),
                      const SizedBox(height: AppSpacing.sm),
                      TextFormField(
                        controller: _nameController,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          hintText: 'e.g. Summer trip',
                          prefixIcon: Icon(AppIcons.groups),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter a group name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _Label(text: 'Base currency'),
                      const SizedBox(height: AppSpacing.sm),
                      DropdownButtonFormField<String>(
                        value: _selectedCurrency,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(AppIcons.payments),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'VND',
                            child: Text('VND (Vietnamese Dong)'),
                          ),
                          DropdownMenuItem(
                            value: 'USD',
                            child: Text('USD (US Dollar)'),
                          ),
                          DropdownMenuItem(
                            value: 'EUR',
                            child: Text('EUR (Euro)'),
                          ),
                          DropdownMenuItem(
                            value: 'JPY',
                            child: Text('JPY (Japanese Yen)'),
                          ),
                          DropdownMenuItem(
                            value: 'KRW',
                            child: Text('KRW (South Korean Won)'),
                          ),
                        ],
                        onChanged: (v) => setState(() {
                          _selectedCurrency = v ?? 'VND';
                        }),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'This currency will be used as the default for all expenses.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        'Member permissions',
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor:
                                      scheme.surfaceContainerHighest,
                                  child: Icon(
                                    AppIcons.person,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: scheme.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: scheme.surface,
                                        width: 2,
                                      ),
                                    ),
                                    child: Icon(
                                      AppIcons.star,
                                      size: 12,
                                      color: scheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'You',
                                    style: textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Group owner',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: scheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(AppIcons.checkCircle, color: Colors.green.shade700),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'As the owner, you can add/remove members and manage group expenses.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Consumer<GroupProvider>(
                builder: (context, provider, child) {
                  return SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: provider.isLoading ? null : _submit,
                      child: provider.isLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('Create group'),
                                SizedBox(width: AppSpacing.sm),
                                Icon(AppIcons.arrowForward, size: 18),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool requiredField;

  const _Label({
    required this.text,
    this.requiredField = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Text.rich(
      TextSpan(
        text: text,
        style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        children: [
          if (requiredField)
            TextSpan(
              text: ' *',
              style: TextStyle(color: scheme.error),
            ),
        ],
      ),
    );
  }
}

