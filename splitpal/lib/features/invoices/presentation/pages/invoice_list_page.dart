import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:splitpal/features/invoices/invoice_provider.dart';
import 'package:splitpal/features/invoices/bill_template_provider.dart';
import 'package:splitpal/features/groups/group_provider.dart';
import 'create_invoice_page.dart';
import 'invoice_capture_mode_page.dart';
import 'invoice_detail_page.dart';
import 'create_bill_template_page.dart';

// ─── Filter definition ──────────────────────────────────────────────────────
class _Filter {
  final String label;
  final IconData icon;
  final String? status; // null = All

  const _Filter({required this.label, required this.icon, this.status});
}

const _filters = [
  _Filter(label: 'All',       icon: Icons.list_alt_rounded),
  _Filter(label: 'Draft',     icon: Icons.edit_note_rounded,   status: 'DRAFT'),
  _Filter(label: 'Submitted', icon: Icons.send_rounded,        status: 'SUBMITTED'),
  _Filter(label: 'Locked',    icon: Icons.lock_rounded,        status: 'LOCKED'),
];

class InvoiceListPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  const InvoiceListPage({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  State<InvoiceListPage> createState() => _InvoiceListPageState();
}

class _InvoiceListPageState extends State<InvoiceListPage> {
  int _selectedFilter = 0;

  static const _brand = Color(0xFFE8472A);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInvoices());
  }

  Future<void> _loadInvoices() async {
    final provider = context.read<InvoiceProvider>();
    await provider.loadInvoices(widget.groupId,
        status: _filters[_selectedFilter].status);
    await provider.loadMyBalance(widget.groupId);
    final gp = context.read<GroupProvider>();
    if (gp.isOwnerOrAdmin) {
      await context.read<BillTemplateProvider>().loadTemplates(widget.groupId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _FilterBar(
            selectedIndex: _selectedFilter,
            onSelected: (i) {
              setState(() => _selectedFilter = i);
              _loadInvoices();
            },
          ),
        ),
      ),
      body: Consumer<InvoiceProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    provider.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadInvoices,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // ── Recurring Bills Section (Owner/Admin only) ───────────────
              Consumer<GroupProvider>(
                builder: (context, groupProvider, _) {
                  if (!groupProvider.isOwnerOrAdmin) return const SizedBox.shrink();
                  return Consumer<BillTemplateProvider>(
                    builder: (context, templateProvider, _) {
                      if (templateProvider.activeTemplates.isEmpty) return const SizedBox.shrink();
                      return Container(
                        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.autorenew, size: 16, color: _brand),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Recurring Bills',
                                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      color: _brand,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: _brand.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${templateProvider.activeTemplates.length}',
                                      style: const TextStyle(color: _brand, fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              height: 86,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                                itemCount: templateProvider.activeTemplates.length,
                                itemBuilder: (context, i) {
                                  final t = templateProvider.activeTemplates[i];
                                  return _TemplateChip(
                                    template: t,
                                    groupId: widget.groupId,
                                    onGenerateNow: () async {
                                      final inv = await templateProvider.generateNow(
                                          widget.groupId, t.id);
                                      if (inv != null && context.mounted) {
                                        _loadInvoices();
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Created: ${inv.title}')),
                                        );
                                      } else if (templateProvider.errorMessage != null && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(templateProvider.errorMessage!),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
              // ── Invoice List ─────────────────────────────────────────────
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadInvoices,
                  child: provider.invoices.isEmpty
                      ? const Center(
                          child: Text('No invoices yet'),
                        )
                      : Builder(
                          builder: (context) {
                            // Sort: DRAFT first, preserve original order within each group
                            final sorted = List.of(provider.invoices)
                              ..sort((a, b) {
                                final aIsDraft = a.status == 'DRAFT' ? 0 : 1;
                                final bIsDraft = b.status == 'DRAFT' ? 0 : 1;
                                return aIsDraft.compareTo(bIsDraft);
                              });
                            return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: sorted.length,
                          itemBuilder: (context, index) {
                            final invoice = sorted[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getStatusColor(invoice.status),
                                  child: Text(
                                    invoice.title[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(child: Text(invoice.title)),
                                    if (invoice.status == 'DRAFT')
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Pending',
                                          style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  '${invoice.items.length} items • ${_statusLabel(invoice.status)}',
                                ),
                                trailing: Text(
                                  CurrencyFormatter.formatVND(invoice.amountTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => InvoiceDetailPage(
                                        groupId: widget.groupId,
                                        invoiceId: invoice.id,
                                      ),
                                    ),
                                  ).then((_) => _loadInvoices());
                                },
                              ),
                            );
                          },
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<GroupProvider>(
        builder: (context, groupProvider, child) {
          if (!groupProvider.isOwnerOrAdmin) {
            return const SizedBox.shrink();
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'fab_recurring',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateBillTemplatePage(
                        groupId: widget.groupId,
                      ),
                    ),
                  ).then((_) => _loadInvoices());
                },
                backgroundColor: _brand,
                tooltip: 'Create recurring bill',
                child: const Icon(Icons.autorenew, color: Colors.white),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.extended(
                heroTag: 'fab_invoice',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => InvoiceCaptureModePage(
                        groupId: widget.groupId,
                      ),
                    ),
                  ).then((_) => _loadInvoices());
                },
                icon: const Icon(Icons.add),
                label: const Text('Create Invoice'),
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'DRAFT':     return 'Draft';
      case 'SUBMITTED': return 'Submitted';
      case 'LOCKED':    return 'Locked';
      case 'PAID':      return 'Paid';
      default:          return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT':     return Colors.orange;
      case 'SUBMITTED': return Colors.blue;
      case 'LOCKED':
      case 'PAID':      return Colors.green;
      default:          return Colors.grey;
    }
  }
}

// ── Custom Filter Bar ─────────────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _brand = Color(0xFFE8472A);

  const _FilterBar({required this.selectedIndex, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: Theme.of(context).appBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = _filters[i];
          final selected = selectedIndex == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: selected ? _brand : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? _brand
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onSelected(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f.icon,
                      size: 14,
                      color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      f.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}




// ── Template Chip Widget ─────────────────────────────────────────────────────
class _TemplateChip extends StatelessWidget {
  final dynamic template;
  final String groupId;
  final VoidCallback onGenerateNow;

  const _TemplateChip({
    required this.template,
    required this.groupId,
    required this.onGenerateNow,
  });

  @override
  Widget build(BuildContext context) {
    final isPaused = template.status == 'PAUSED';
    return GestureDetector(
      onLongPress: onGenerateNow,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isPaused
              ? Colors.grey.withOpacity(0.2)
              : const Color(0xFFE8472A).withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPaused
                ? Colors.grey.withOpacity(0.4)
                : const Color(0xFFE8472A).withOpacity(0.3),
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
                  color: isPaused ? Colors.grey : const Color(0xFFE8472A),
                ),
                const SizedBox(width: 4),
                Text(
                  template.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isPaused ? Colors.grey : const Color(0xFFE8472A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              template.cycleLabel,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
            Text(
              isPaused
                  ? 'Paused'
                  : '${template.daysUntilNext} days left',
              style: TextStyle(
                fontSize: 10,
                color: isPaused ? Colors.grey : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
