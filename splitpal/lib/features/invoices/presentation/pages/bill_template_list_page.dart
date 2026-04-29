import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/invoices/bill_template_provider.dart';
import 'package:splitpal/models/bill_template.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/icons/app_icons.dart';
import 'create_bill_template_page.dart';

/// Manage recurring bill templates list page.
class BillTemplateListPage extends StatefulWidget {
  final String groupId;

  const BillTemplateListPage({Key? key, required this.groupId})
      : super(key: key);

  @override
  State<BillTemplateListPage> createState() => _BillTemplateListPageState();
}

class _BillTemplateListPageState extends State<BillTemplateListPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await context.read<BillTemplateProvider>().loadTemplates(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Recurring Bills', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              'Manage automated templates',
              style: TextStyle(fontSize: 12, color: scheme.onPrimary.withOpacity(0.8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.refresh),
            onPressed: _load,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Consumer<BillTemplateProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.templates.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.templates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: scheme.error),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    provider.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  ElevatedButton.icon(
                    onPressed: _load,
                    icon: const Icon(AppIcons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final templates = provider.templates;

          if (templates.isEmpty) {
            return Center(
              child: Padding(
                padding: AppSpacing.pagePadding,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(AppIcons.refresh, size: 40, color: scheme.primary),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'No templates found',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Create a template to automatically generate bills daily, weekly, or monthly.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    FilledButton.icon(
                      onPressed: () => _openCreate(context),
                      icon: const Icon(AppIcons.add),
                      label: const Text('Create first template'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.md),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 100),
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final t = templates[index];
                return _TemplateCard(
                  template: t,
                  groupId: widget.groupId,
                  onRefresh: _load,
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreate(context),
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        icon: const Icon(AppIcons.add),
        label: const Text('Create Template'),
        heroTag: 'fab_create_template',
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateBillTemplatePage(groupId: widget.groupId),
      ),
    ).then((_) => _load());
  }
}

// ─── Template Card ────────────────────────────────────────────────────────────

class _TemplateCard extends StatefulWidget {
  final BillTemplate template;
  final String groupId;
  final VoidCallback onRefresh;

  const _TemplateCard({
    required this.template,
    required this.groupId,
    required this.onRefresh,
  });

  @override
  State<_TemplateCard> createState() => _TemplateCardState();
}

class _TemplateCardState extends State<_TemplateCard> {
  bool _isActionLoading = false;

  BillTemplate get t => widget.template;

  Color _getStatusColor(ColorScheme scheme) {
    switch (t.status) {
      case 'ACTIVE': return scheme.primary;
      case 'PAUSED': return Colors.orange.shade600;
      case 'ARCHIVED': return scheme.outline;
      default: return scheme.outlineVariant;
    }
  }

  String get _statusLabel {
    switch (t.status) {
      case 'ACTIVE': return 'Running';
      case 'PAUSED': return 'Paused';
      case 'ARCHIVED': return 'Archived';
      default: return t.status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final statusColor = _getStatusColor(scheme);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // ── Header ─────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: t.isActive
                          ? scheme.primaryContainer
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                    ),
                    child: Icon(
                      t.isActive ? Icons.autorenew : Icons.pause_circle_outline,
                      color: t.isActive ? scheme.primary : scheme.outline,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t.cycleLabel,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        if (t.description?.isNotEmpty ?? false)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              t.description!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant.withOpacity(0.7),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(AppRadii.pill),
                    ),
                    child: Text(
                      _statusLabel.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Items preview ────────────────────────────────────────────────
            if (t.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  children: [
                    Divider(color: scheme.outlineVariant, height: 1),
                    const SizedBox(height: AppSpacing.md),
                    ...t.items.map<Widget>((item) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.receipt_outlined, size: 14, color: scheme.outline),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            item.amount == 0
                                ? 'Enter later'
                                : CurrencyFormatter.formatVND(item.amount),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: item.amount == 0 ? Colors.orange : scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )),
                    if (t.totalAmount > 0)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            CurrencyFormatter.formatVND(t.totalAmount),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ),
              ),

            // ── Next bill + Payer ────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      t.isActive
                          ? 'Next bill: ${t.daysUntilNext == 0 ? "Today" : "in ${t.daysUntilNext} days"}'
                          : 'Paused',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (t.lastGeneratedAt != null)
                    Text(
                      'Last run: ${_formatDate(t.lastGeneratedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.outline,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            // ── Actions ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
              child: _isActionLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: AppSpacing.sm,
                      children: [
                        // Run Now
                        if (t.isActive)
                          _ActionChip(
                            icon: Icons.flash_on,
                            label: 'Run now',
                            color: Colors.blue,
                            onTap: () => _generateNow(context),
                          ),

                        // Pause / Resume
                        if (t.isActive)
                          _ActionChip(
                            icon: Icons.pause,
                            label: 'Pause',
                            color: Colors.orange,
                            onTap: () => _pause(context),
                          )
                        else if (t.isPaused)
                          _ActionChip(
                            icon: Icons.play_arrow,
                            label: 'Resume',
                            color: Colors.green,
                            onTap: () => _resume(context),
                          ),

                        // Archive
                        if (t.status != 'ARCHIVED')
                          _ActionChip(
                            icon: Icons.archive_outlined,
                            label: 'Archive',
                            color: scheme.outline,
                            onTap: () => _archive(context),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generateNow(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        title: const Text('Generate Bill Now'),
        content: Text(
          'Do you want to generate a bill from template "${t.name}" now?\n\nThe bill will be created in DRAFT status for you to review.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.blue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Run now'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    final provider = context.read<BillTemplateProvider>();
    final invoice = await provider.generateNow(widget.groupId, t.id);
    setState(() => _isActionLoading = false);

    if (!mounted) return;
    if (invoice != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created bill: ${invoice.title}'),
          backgroundColor: Colors.green,
        ),
      );
      widget.onRefresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to create'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _pause(BuildContext context) async {
    setState(() => _isActionLoading = true);
    final provider = context.read<BillTemplateProvider>();
    final ok = await provider.pauseTemplate(widget.groupId, t.id);
    setState(() => _isActionLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Paused template "${t.name}"' : (provider.errorMessage ?? 'Error')),
      backgroundColor: ok ? Colors.orange : Theme.of(context).colorScheme.error,
    ));
    if (ok) widget.onRefresh();
  }

  Future<void> _resume(BuildContext context) async {
    setState(() => _isActionLoading = true);
    final provider = context.read<BillTemplateProvider>();
    final ok = await provider.resumeTemplate(widget.groupId, t.id);
    setState(() => _isActionLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Resumed template "${t.name}"' : (provider.errorMessage ?? 'Error')),
      backgroundColor: ok ? Colors.green : Theme.of(context).colorScheme.error,
    ));
    if (ok) widget.onRefresh();
  }

  Future<void> _archive(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
        title: const Text('Archive template'),
        content: Text('Are you sure you want to archive "${t.name}"?\n\nThis template will no longer generate new bills.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.outline),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isActionLoading = true);
    final provider = context.read<BillTemplateProvider>();
    final ok = await provider.archiveTemplate(widget.groupId, t.id);
    setState(() => _isActionLoading = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? 'Archived "${t.name}"' : (provider.errorMessage ?? 'Error')),
      backgroundColor: ok ? Colors.grey : Theme.of(context).colorScheme.error,
    ));
    if (ok) widget.onRefresh();
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}

// ─── Small action chip button ─────────────────────────────────────────────────

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
