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

    final filters = [
      (InvoiceStatusFilterValue.all, 'All', AppIcons.invoices),
      (InvoiceStatusFilterValue.submitted, 'Submitted', AppIcons.submitted),
      (InvoiceStatusFilterValue.locked, 'Locked', AppIcons.locked),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = value == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    f.$3,
                    size: 16,
                    color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f.$2,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              selected: isSelected,
              showCheckmark: false,
              backgroundColor: scheme.surface,
              selectedColor: scheme.primary,
              side: BorderSide(
                color: isSelected ? scheme.primary : scheme.outlineVariant.withOpacity(0.5),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
              onSelected: (selected) {
                if (selected) onChanged(f.$1);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}
