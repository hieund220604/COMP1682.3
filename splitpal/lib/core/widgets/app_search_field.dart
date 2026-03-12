import 'package:flutter/material.dart';

import '../icons/app_icons.dart';
import '../theme/app_tokens.dart';

class AppSearchField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final String hintText;

  const AppSearchField({
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.hintText = 'Search...',
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(AppIcons.search, color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

