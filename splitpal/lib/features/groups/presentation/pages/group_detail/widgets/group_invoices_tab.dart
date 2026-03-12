import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/core/constants/app_constants.dart';
import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/widgets/app_empty_state.dart';
import 'package:splitpal/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:splitpal/features/invoices/presentation/providers/invoice_provider.dart';

import 'invoice_status_filter.dart';

class GroupInvoicesTab extends StatefulWidget {
  final String groupId;
  final bool isOwnerOrAdmin;
  final VoidCallback? onCreateInvoice;

  const GroupInvoicesTab({
    super.key,
    required this.groupId,
    required this.isOwnerOrAdmin,
    this.onCreateInvoice,
  });

  @override
  State<GroupInvoicesTab> createState() => _GroupInvoicesTabState();
}

class _GroupInvoicesTabState extends State<GroupInvoicesTab> {
  InvoiceStatusFilterValue _filter = InvoiceStatusFilterValue.all;

  @override
  void initState() {
    super.initState();
    // Ensure an initial load even if the user lands on this tab first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    return context.read<InvoiceProvider>().loadInvoices(
          widget.groupId,
          status: invoiceStatusToParam(_filter),
        );
  }

  void _setFilter(InvoiceStatusFilterValue next) {
    if (next == _filter) return;
    setState(() => _filter = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat(AppConstants.displayDateFormat);

    return Consumer<InvoiceProvider>(
      builder: (context, provider, child) {
        final invoices = provider.invoices;
        final scheme = Theme.of(context).colorScheme;

        Widget content;
        if (provider.isLoading && invoices.isEmpty) {
          content = const Center(child: CircularProgressIndicator());
        } else if (provider.errorMessage != null && invoices.isEmpty) {
          content = AppEmptyState(
            icon: AppIcons.invoices,
            title: 'Could not load invoices',
            message: provider.errorMessage,
            actionLabel: 'Retry',
            onAction: _load,
          );
        } else if (invoices.isEmpty) {
          content = AppEmptyState(
            icon: AppIcons.invoices,
            title: 'No invoices yet',
            message: widget.isOwnerOrAdmin
                ? 'Create the first invoice to start tracking expenses.'
                : 'Ask an admin to create an invoice for this group.',
            actionLabel: widget.onCreateInvoice == null ? null : 'New invoice',
            onAction: widget.onCreateInvoice,
          );
        } else {
          content = RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                120,
              ),
              itemCount: invoices.length,
              itemBuilder: (context, index) {
                final inv = invoices[index];
                final status = inv.status.toUpperCase();
                final statusColor = _statusColor(status, scheme);
                final statusIcon = _statusIcon(status);

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppCard(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => InvoiceDetailPage(
                            groupId: widget.groupId,
                            invoiceId: inv.id,
                          ),
                        ),
                      ).then((_) => _load());
                    },
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Icon(statusIcon, color: statusColor),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      inv.title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(fontWeight: FontWeight.w800),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  _StatusPill(
                                    label: _statusLabel(status),
                                    color: statusColor,
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Row(
                                children: [
                                  Icon(
                                    AppIcons.invoices,
                                    size: 16,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    '${inv.items.length} items',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Icon(
                                    AppIcons.calendar,
                                    size: 16,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    df.format(inv.invoiceDate),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                CurrencyFormatter.formatCurrency(
                                  inv.amountTotal,
                                  inv.currency,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InvoiceStatusFilter(
                      value: _filter,
                      onChanged: _setFilter,
                    ),
                  ),
                if (widget.onCreateInvoice != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  IconButton(
                    tooltip: 'New invoice',
                    onPressed: widget.onCreateInvoice,
                    color: scheme.primary,
                    icon: const Icon(AppIcons.add),
                  ),
                ],
              ],
            ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }
}

Color _statusColor(String status, ColorScheme scheme) {
  switch (status) {
    case 'SUBMITTED':
      return AppColors.pomegranate;
    case 'LOCKED':
      return scheme.tertiary;
    case 'DRAFT':
    default:
      return scheme.onSurfaceVariant;
  }
}

IconData _statusIcon(String status) {
  switch (status) {
    case 'SUBMITTED':
      return AppIcons.submitted;
    case 'LOCKED':
      return AppIcons.locked;
    case 'DRAFT':
    default:
      return AppIcons.draft;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'SUBMITTED':
      return 'Submitted';
    case 'LOCKED':
      return 'Locked';
    case 'DRAFT':
    default:
      return 'Draft';
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: color,
          fontSize: 11,
        ),
      ),
    );
  }
}
