import 'package:flutter/material.dart';

import 'package:splitpal/core/icons/app_icons.dart';

enum InvoiceStatusFilterValue { all, draft, submitted, locked }

String? invoiceStatusToParam(InvoiceStatusFilterValue value) {
  switch (value) {
    case InvoiceStatusFilterValue.all:
      return null;
    case InvoiceStatusFilterValue.draft:
      return 'DRAFT';
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
      (InvoiceStatusFilterValue.all, 'All', AppIcons.invoices, scheme.onSurface),
      (InvoiceStatusFilterValue.draft, 'Draft', AppIcons.draft, scheme.secondary),
      (InvoiceStatusFilterValue.submitted, 'Submitted', AppIcons.submitted, scheme.primary),
      (InvoiceStatusFilterValue.locked, 'Locked', AppIcons.locked, Colors.green.shade600),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((f) {
          final isSelected = value == f.$1;
          final color = f.$4;

          return Padding(
            padding: EdgeInsets.only(right: f == filters.last ? 0 : 8.0),
            child: InkWell(
              onTap: () {
                if (!isSelected) onChanged(f.$1);
              },
              borderRadius: BorderRadius.circular(999),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? color.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: isSelected ? color : scheme.outlineVariant.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f.$3,
                      size: 16,
                      color: isSelected ? color : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      f.$2,
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected ? color : scheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
