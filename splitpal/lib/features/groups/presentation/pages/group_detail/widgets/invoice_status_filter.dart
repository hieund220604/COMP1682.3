import 'package:flutter/material.dart';

import 'package:splitpal/core/icons/app_icons.dart';

enum InvoiceStatusFilterValue { all, submitted, locked }

String? invoiceStatusToParam(InvoiceStatusFilterValue value) {
  switch (value) {
    case InvoiceStatusFilterValue.all:
      return null;
    case InvoiceStatusFilterValue.submitted:
      return 'SUBMITTED';
    case InvoiceStatusFilterValue.locked:
      return 'LOCKED';
  }
}

class InvoiceStatusFilter extends StatelessWidget {
  final InvoiceStatusFilterValue value;
  final ValueChanged<InvoiceStatusFilterValue> onChanged;

  const InvoiceStatusFilter({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return SegmentedButton<InvoiceStatusFilterValue>(
      showSelectedIcon: false,
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary.withAlpha(18);
          }
          return scheme.surface;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return scheme.primary;
          }
          return scheme.onSurfaceVariant;
        }),
        side: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return BorderSide(
            color: selected
                ? scheme.primary.withAlpha(90)
                : scheme.outlineVariant.withAlpha(160),
          );
        }),
        textStyle: WidgetStateProperty.all(textTheme.labelMedium),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
      segments: const [
        ButtonSegment(
          value: InvoiceStatusFilterValue.all,
          label: Text('All'),
          icon: Icon(AppIcons.invoices),
        ),
        ButtonSegment(
          value: InvoiceStatusFilterValue.submitted,
          label: Text('Submitted'),
          icon: Icon(AppIcons.submitted),
        ),
        ButtonSegment(
          value: InvoiceStatusFilterValue.locked,
          label: Text('Locked'),
          icon: Icon(AppIcons.locked),
        ),
      ],
      selected: {value},
      onSelectionChanged: (next) {
        if (next.isEmpty) return;
        onChanged(next.first);
      },
    );
  }
}
