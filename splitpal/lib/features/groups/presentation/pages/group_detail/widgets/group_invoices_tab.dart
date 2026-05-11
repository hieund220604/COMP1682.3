import 'dart:async';
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
import 'package:splitpal/features/invoices/bill_template_provider.dart';
import 'package:splitpal/features/invoices/presentation/pages/bill_template_list_page.dart';
import 'package:splitpal/features/invoices/presentation/pages/create_bill_template_page.dart';
import 'package:splitpal/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:splitpal/features/invoices/invoice_provider.dart';
import 'package:splitpal/models/bill_template.dart';

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
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _sortBy = 'invoiceDate';
  String _sortOrder = 'desc';

  @override
  void initState() {
    super.initState();
    // Ensure an initial load even if the user lands on this tab first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    await context.read<InvoiceProvider>().loadInvoices(
          widget.groupId,
          status: invoiceStatusToParam(_filter),
          searchQuery: _searchController.text.trim(),
          sortBy: _sortBy,
          sortOrder: _sortOrder,
        );
    // Guard: widget may have been disposed while the first await was in flight
    if (!mounted) return;
    // Load templates for Owner/Admin view
    if (widget.isOwnerOrAdmin) {
      await context.read<BillTemplateProvider>().loadTemplates(widget.groupId);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _load();
    });
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
            // ── Recurring Bills Section (Owner/Admin only) ──────────────────
            if (widget.isOwnerOrAdmin)
              Consumer<BillTemplateProvider>(
                builder: (context, templateProvider, _) {
                  final templates = templateProvider.activeTemplates;
                  if (templates.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 4),
                        child: Row(
                          children: [
                            Icon(Icons.autorenew, size: 15, color: scheme.primary),
                            const SizedBox(width: 6),
                            Text(
                              'Recurring Bills',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${templates.length}',
                                style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 11, fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Spacer(),
                            // Manage templates button
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BillTemplateListPage(groupId: widget.groupId),
                                  ),
                                ).then((_) => _load());
                              },
                              child: Text(
                                'Manage',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 2, AppSpacing.lg, AppSpacing.sm),
                          itemCount: templates.length,
                          itemBuilder: (context, i) {
                            final t = templates[i];
                            return _TemplateChipCard(
                              template: t,
                              groupId: widget.groupId,
                              onRefresh: _load,
                            );
                          },
                        ),
                      ),
                      Divider(height: 1, color: scheme.outlineVariant.withOpacity(0.5)),
                    ],
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                            decoration: InputDecoration(
                              hintText: 'Search by title, date...',
                              hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.7), fontSize: 15, fontWeight: FontWeight.w400),
                              prefixIcon: Icon(Icons.search, size: 20, color: scheme.onSurfaceVariant),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.cancel, size: 18, color: scheme.onSurfaceVariant),
                                      onPressed: () {
                                        _searchController.clear();
                                        _onSearchChanged('');
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              isDense: true,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: scheme.outlineVariant.withOpacity(0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _showSortModal(context),
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Icon(
                                Icons.tune, 
                                size: 22, 
                                color: (_sortBy != 'invoiceDate' || _sortOrder != 'desc') ? scheme.primary : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InvoiceStatusFilter(
                    value: _filter,
                    onChanged: _setFilter,
                  ),
                ],
              ),
            ),
            Expanded(child: content),
          ],
        );
      },
    );
  }

  void _showSortModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _SortBottomSheet(
        currentSortBy: _sortBy,
        currentSortOrder: _sortOrder,
        onSortApplied: (sortBy, sortOrder) {
          setState(() {
            _sortBy = sortBy;
            _sortOrder = sortOrder;
          });
          _load();
        },
      ),
    );
  }
}

Color _statusColor(String status, ColorScheme scheme) {
  switch (status) {
    case 'SUBMITTED':
      return scheme.primary;
    case 'LOCKED':
      return Colors.green.shade600;
    case 'DRAFT':
    default:
      return scheme.outline;
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
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: Colors.white,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ── Template Chip Card ────────────────────────────────────────────────────────
/// Chip displayed in the horizontal scroll list.
/// Tap → opens a bottom sheet menu with actions.
class _TemplateChipCard extends StatelessWidget {
  final BillTemplate template;
  final String groupId;
  final VoidCallback onRefresh;

  const _TemplateChipCard({
    required this.template,
    required this.groupId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPaused = template.isPaused;

    return GestureDetector(
      onTap: () => _showMenu(context),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPaused
              ? scheme.surfaceContainerLowest
              : scheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: isPaused ? scheme.outlineVariant : scheme.primary.withOpacity(0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPaused ? Icons.pause_circle_outline : Icons.autorenew,
                  size: 13,
                  color: isPaused ? scheme.onSurfaceVariant : scheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  template.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: isPaused ? scheme.onSurfaceVariant : scheme.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.more_horiz, size: 12, color: scheme.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              template.cycleLabel,
              style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
            ),
            Text(
              isPaused ? 'Paused' : '${template.daysUntilNext} days left',
              style: TextStyle(
                fontSize: 10,
                color: isPaused ? scheme.error : Colors.orange.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final provider = context.read<BillTemplateProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.autorenew, color: scheme.onPrimaryContainer, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            template.cycleLabel,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 8),

                // Generate now
                if (template.isActive)
                  _menuItem(
                    context: ctx,
                    icon: Icons.flash_on,
                    label: 'Generate Invoice Now',
                    subtitle: 'Create a DRAFT without waiting for the scheduler',
                    color: Colors.blue,
                    onTap: () async {
                      Navigator.pop(ctx);
                      final inv = await provider.generateNow(groupId, template.id);
                      if (!context.mounted) return;
                      if (inv != null) {
                        onRefresh();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Created: ${inv.title}'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(provider.errorMessage ?? 'Generation failed'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),

                // Pause / Resume
                if (template.isActive)
                  _menuItem(
                    context: ctx,
                    icon: Icons.pause,
                    label: 'Pause',
                    subtitle: 'Stop auto-generating invoices',
                    color: Colors.orange,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await provider.pauseTemplate(groupId, template.id);
                      onRefresh();
                    },
                  )
                else if (template.isPaused)
                  _menuItem(
                    context: ctx,
                    icon: Icons.play_arrow,
                    label: 'Resume',
                    subtitle: 'Re-enable auto-generation',
                    color: Colors.green,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await provider.resumeTemplate(groupId, template.id);
                      onRefresh();
                    },
                  ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _menuItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      onTap: onTap,
    );
  }
}

class _SortBottomSheet extends StatelessWidget {
  final String currentSortBy;
  final String currentSortOrder;
  final void Function(String sortBy, String sortOrder) onSortApplied;

  const _SortBottomSheet({
    required this.currentSortBy,
    required this.currentSortOrder,
    required this.onSortApplied,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Sort Invoices',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          _buildOption(context, 'Newest Date', 'invoiceDate', 'desc', Icons.calendar_today),
          _buildOption(context, 'Oldest Date', 'invoiceDate', 'asc', Icons.event_note),
          _buildOption(context, 'Highest Amount', 'amountTotal', 'desc', Icons.arrow_upward),
          _buildOption(context, 'Lowest Amount', 'amountTotal', 'asc', Icons.arrow_downward),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String label, String sortBy, String sortOrder, IconData icon) {
    final scheme = Theme.of(context).colorScheme;
    final isSelected = currentSortBy == sortBy && currentSortOrder == sortOrder;

    return InkWell(
      onTap: () {
        onSortApplied(sortBy, sortOrder);
        Navigator.pop(context);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primaryContainer.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? scheme.primary.withOpacity(0.5) : scheme.outlineVariant.withOpacity(0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? scheme.primary : scheme.onSurfaceVariant),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
