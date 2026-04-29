import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/models/invoice.dart';
import 'package:splitpal/features/invoices/invoice_provider.dart';
import 'package:splitpal/features/invoices/bill_template_provider.dart';
import 'package:splitpal/features/groups/group_provider.dart';
import 'package:splitpal/features/auth/auth_provider.dart';
import 'payment_page.dart';
import 'edit_draft_invoice_page.dart';

class InvoiceDetailPage extends StatefulWidget {
  static const routeName = '/invoice-detail';
  
  final String groupId;
  final String invoiceId;

  const InvoiceDetailPage({
    Key? key,
    required this.groupId,
    required this.invoiceId,
  }) : super(key: key);

  @override
  State<InvoiceDetailPage> createState() => _InvoiceDetailPageState();
}

class _InvoiceDetailPageState extends State<InvoiceDetailPage> {
  bool _isSubmitting = false;
  Invoice? _currentInvoice;
  bool _isLoading = true;
  bool _isPayingNow = false;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetail();
  }

  Future<void> _loadInvoiceDetail() async {
    setState(() => _isLoading = true);
    
    final provider = context.read<InvoiceProvider>();
    await provider.fetchInvoiceById(widget.groupId, widget.invoiceId);
    
    if (provider.selectedInvoice != null) {
      setState(() {
        _currentInvoice = provider.selectedInvoice!;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  /// Confirm a DRAFT recurring invoice → SUBMITTED.
  Future<void> _confirmDraftInvoice() async {
    if (_currentInvoice == null) return;

    // Validate: check if any items have amount=0
    final zeroItems = _currentInvoice!.items.where((i) => i.amount <= 0).toList();
    if (zeroItems.isNotEmpty) {
      final names = zeroItems.map((i) => '"${i.name}"').join(', ');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Text('Items missing amounts'),
            ],
          ),
          content: Text(
            'The following items have no amount: $names.\n\nPlease tap "Edit" to enter amounts before confirming.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8472A), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(ctx);
                _navigateToEditDraft();
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit Now'),
            ),
          ],
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm Recurring Invoice'),
        content: const Text(
          'Once confirmed, the invoice will be sent to all members and cannot be reversed.\n\nAre you sure you want to confirm?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE8472A), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final provider = context.read<BillTemplateProvider>();
    final invoice = await provider.confirmDraft(widget.groupId, _currentInvoice!.id);
    setState(() => _isSubmitting = false);

    if (!mounted) return;
    if (invoice != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice confirmed and sent to members!'),
          backgroundColor: const Color(0xFFE8472A),
        ),
      );
      await _loadInvoiceDetail();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Confirmation failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// Navigate to edit DRAFT invoice page.
  Future<void> _navigateToEditDraft() async {
    if (_currentInvoice == null) return;
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EditDraftInvoicePage(
          groupId: widget.groupId,
          invoice: _currentInvoice!,
        ),
      ),
    );
    // Reload if changes were made
    if (result == true && mounted) {
      await _loadInvoiceDetail();
    }
  }

  Future<void> _createPaymentRequest() async {
    final provider = context.read<InvoiceProvider>();
    final success = await provider.createPaymentRequest(widget.groupId);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment request created')),
        );
        // Navigate to payment page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentPage(groupId: widget.groupId),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to create payment request'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Check if current user owes money on this invoice
  bool _doesUserOweMoneyOnInvoice(String currentUserId) {
    if (_currentInvoice == null) return false;
    
    // User doesn't owe if they are the uploader
    if (_currentInvoice!.uploadedBy == currentUserId) return false;
    
    // Check if user is assigned to any item
    for (final item in _currentInvoice!.items) {
      if (item.assignedTo.contains(currentUserId)) {
        return true;
      }
    }
    
    return false;
  }

  Future<void> _handlePayNow() async {
    if (_currentInvoice == null) return;
    
    setState(() => _isPayingNow = true);
    
    final invoiceProvider = context.read<InvoiceProvider>();
    
    // Create payment request for this invoice
    final success = await invoiceProvider.createPaymentRequest(widget.groupId);
    
    setState(() => _isPayingNow = false);
    
    if (success && mounted) {
      // Navigate to payment page
      Navigator.pushNamed(
        context,
        '/payment',
        arguments: {'groupId': widget.groupId},
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(invoiceProvider.errorMessage ?? 'Failed to create payment request'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invoice Details'),
          centerTitle: true,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentInvoice == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Invoice Details'),
          centerTitle: true,
        ),
        body: const Center(child: Text('Invoice not found')),
      );
    }

    final invoice = _currentInvoice!;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Details'),
        centerTitle: true,
        actions: [
          if (invoice.status == 'DRAFT' && context.read<GroupProvider>().isOwnerOrAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit amounts',
              onPressed: _navigateToEditDraft,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInvoiceDetail,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // DRAFT Recurring Banner
              if (invoice.status == 'DRAFT')
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: scheme.onSurfaceVariant, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'This recurring invoice is pending confirmation. You can edit amounts before submitting.',
                          style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              // Status Badge
              _buildStatusBadge(context),
              const SizedBox(height: AppSpacing.lg),

              // Title Card
              _buildInfoCard(
                context,
                icon: Icons.receipt_long,
                title: 'Invoice Title',
                content: invoice.title,
              ),
              const SizedBox(height: AppSpacing.md),

              // Note Card
              if (invoice.note?.isNotEmpty ?? false) ...[
                _buildInfoCard(
                  context,
                  icon: Icons.note,
                  title: 'Note',
                  content: invoice.note!,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Uploaded By Card
              _buildInfoCard(
                context,
                icon: Icons.person,
                title: 'Uploaded By',
                content: invoice.uploadedByName,
              ),
              const SizedBox(height: AppSpacing.md),

              // Date Card
              _buildInfoCard(
                context,
                icon: Icons.calendar_today,
                title: 'Created Date',
                content: _formatDate(invoice.createdAt),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Items Section
              Text(
                'INVOICE ITEMS',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              ...invoice.items.asMap().entries.map((entry) {
                return _buildItemCard(context, entry.key + 1, entry.value);
              }).toList(),

              const SizedBox(height: AppSpacing.xl),

              // Total Card
              AppCard(
                color: scheme.primaryContainer,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          invoice.hasCurrencyConversion ? 'Original Total' : 'Total Amount',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatCurrency(invoice.amountTotal, invoice.currency),
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.onPrimaryContainer,
                          ),
                        ),
                      ],
                    ),
                    if (invoice.hasCurrencyConversion) ...[
                      const SizedBox(height: AppSpacing.md),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: scheme.surface.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Converted (${invoice.baseCurrency ?? 'VND'})',
                                  style: textTheme.bodyMedium,
                                ),
                                Text(
                                  CurrencyFormatter.formatCurrency(
                                    invoice.convertedAmountTotal!, invoice.baseCurrency ?? 'VND'),
                                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Row(
                              children: [
                                Icon(Icons.lock_outline, size: 12, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 4),
                                Text(
                                  '1 ${invoice.currency} = ${invoice.exchangeRate!.toStringAsFixed(invoice.exchangeRate! < 1 ? 6 : 2)} ${invoice.baseCurrency ?? 'VND'}',
                                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons
              Consumer<AuthProvider>(builder: (context, authProvider, _) {
                final currentUserId = authProvider.user?.id;
                final isOwnerOrAdmin = context.read<GroupProvider>().isOwnerOrAdmin;
                final userOwes = currentUserId != null && _doesUserOweMoneyOnInvoice(currentUserId);
                
                return Column(
                  children: [
                    // Admin/Owner buttons
                    if (isOwnerOrAdmin) ...[
                      if (invoice.status == 'DRAFT') ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _navigateToEditDraft,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Amounts'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _confirmDraftInvoice,
                            icon: const Icon(Icons.check_circle_outline),
                            label: _isSubmitting
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('Confirm & Notify', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ],
                    
                    // Pay Now button for non-admin users who owe money
                    if (!isOwnerOrAdmin && invoice.status == 'SUBMITTED' && userOwes) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton.icon(
                          onPressed: _isPayingNow ? null : _handlePayNow,
                          icon: const Icon(Icons.payment),
                          label: _isPayingNow
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Pay Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                    const SizedBox(height: 100),
                  ],
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    if (_currentInvoice == null) return const SizedBox.shrink();
    
    final scheme = Theme.of(context).colorScheme;
    Color badgeColor;
    String statusText;

    switch (_currentInvoice!.status) {
      case 'DRAFT':
        badgeColor = scheme.outline;
        statusText = 'Draft';
        break;
      case 'SUBMITTED':
        badgeColor = scheme.primary;
        statusText = 'Submitted';
        break;
      case 'PAID':
        badgeColor = Colors.blue.shade600;
        statusText = 'Paid';
        break;
      case 'LOCKED':
        badgeColor = Colors.green.shade600;
        statusText = 'Locked';
        break;
      default:
        badgeColor = scheme.outlineVariant;
        statusText = _currentInvoice!.status;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          statusText.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: scheme.onSurfaceVariant, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  content,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(BuildContext context, int index, InvoiceItem item) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ITEM $index',
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                CurrencyFormatter.formatCurrency(item.amount, _currentInvoice!.currency),
                style: textTheme.titleMedium?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            item.name,
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (item.assignedToNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: item.assignedToNames.map<Widget>((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Text(
                    name,
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Share per person: ${CurrencyFormatter.formatCurrency(item.sharePerPerson, _currentInvoice!.currency)}',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
