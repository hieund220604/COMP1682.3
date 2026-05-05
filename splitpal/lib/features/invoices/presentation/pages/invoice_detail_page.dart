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
  bool _isDeleting = false;

  // Brand-derived palette
  static const _brand = AppColors.brand;

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
              style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
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
            style: ElevatedButton.styleFrom(backgroundColor: _brand, foregroundColor: Colors.white),
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
          backgroundColor: _brand,
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

  /// Delete invoice after user confirmation.
  Future<void> _deleteInvoice() async {
    if (_currentInvoice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text(
          'Are you sure you want to delete "${_currentInvoice!.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeleting = true);

    final provider = context.read<InvoiceProvider>();
    final ok = await provider.deleteInvoice(widget.groupId, widget.invoiceId);

    if (!mounted) return;
    setState(() => _isDeleting = false);

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invoice deleted'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true); // return true to signal deletion
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to delete invoice'),
          backgroundColor: Colors.red,
        ),
      );
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

  /// Whether the current user can edit this invoice.
  /// DRAFT: owner/admin can edit. SUBMITTED: uploader OR owner/admin.
  bool _canEditInvoice(Invoice invoice) {
    if (invoice.isLocked) return false;
    final currentUserId = context.read<AuthProvider>().user?.id;
    if (currentUserId == null) return false;
    if (context.read<GroupProvider>().isOwnerOrAdmin) return true;
    return invoice.uploadedBy == currentUserId;
  }

  /// Whether the current user can delete this invoice.
  /// DRAFT: owner/admin can delete. SUBMITTED: uploader OR owner/admin.
  bool _canDeleteInvoice(Invoice invoice) {
    if (invoice.isLocked) return false;
    final currentUserId = context.read<AuthProvider>().user?.id;
    if (currentUserId == null) return false;
    if (context.read<GroupProvider>().isOwnerOrAdmin) return true;
    return invoice.uploadedBy == currentUserId;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          if (!invoice.isLocked) ...[
            if (invoice.status == 'DRAFT' || _canEditInvoice(invoice))
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit invoice',
                onPressed: _navigateToEditDraft,
              ),
            if (invoice.status == 'DRAFT' || _canDeleteInvoice(invoice))
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                tooltip: 'Delete invoice',
                onPressed: _isDeleting ? null : _deleteInvoice,
              ),
          ],
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
                    color: isDark
                        ? _brand.withOpacity(0.08)
                        : AppColors.brandSurface,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: _brand.withOpacity(isDark ? 0.2 : 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: _brand.withOpacity(0.7), size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'This recurring invoice is pending confirmation. You can edit amounts before submitting.',
                          style: textTheme.bodySmall?.copyWith(
                            color: isDark
                                ? _brand.withOpacity(0.85)
                                : AppColors.brandDark,
                          ),
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

              const SizedBox(height: AppSpacing.md),

              // Date Card
              _buildInfoCard(
                context,
                icon: Icons.calendar_today,
                title: 'Created Date',
                content: _formatDate(invoice.createdAt),
              ),

              if (invoice.imageUrl?.isNotEmpty ?? false) ...[
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'ATTACHED RECEIPT',
                  style: textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Image.network(
                    invoice.imageUrl!,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Column(
                          children: [
                            Icon(Icons.broken_image_outlined, 
                              size: 48, 
                              color: Theme.of(context).colorScheme.outline
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Image not available',
                              style: TextStyle(color: Theme.of(context).colorScheme.outline),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
              
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

              // Per-Person Breakdown
              _buildPerPersonBreakdown(context, invoice, isDark),
              const SizedBox(height: AppSpacing.lg),

              // Total Card — brand-tinted instead of primaryContainer
              _buildTotalCard(context, invoice, isDark),
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
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isDeleting ? null : _deleteInvoice,
                            icon: _isDeleting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                            label: Text(
                              _isDeleting ? 'Deleting...' : 'Delete Invoice',
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Theme.of(context).colorScheme.error.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      ],
                      // SUBMITTED invoices — allow edit + delete for the uploader
                      if (invoice.status == 'SUBMITTED' && !invoice.isLocked && _canEditInvoice(invoice)) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: _navigateToEditDraft,
                            icon: const Icon(Icons.edit_outlined),
                            label: const Text('Edit Invoice'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: _isDeleting ? null : _deleteInvoice,
                            icon: _isDeleting
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                            label: Text(
                              _isDeleting ? 'Deleting...' : 'Delete Invoice',
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Theme.of(context).colorScheme.error.withOpacity(0.5)),
                            ),
                          ),
                        ),
                      ],
                    ] else if (!isOwnerOrAdmin && invoice.status == 'SUBMITTED' && !invoice.isLocked && _canDeleteInvoice(invoice)) ...[
                      // Non-admin uploaders can still edit/delete their own
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: _navigateToEditDraft,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit Invoice'),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _isDeleting ? null : _deleteInvoice,
                          icon: _isDeleting
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                          label: Text(
                            _isDeleting ? 'Deleting...' : 'Delete Invoice',
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Theme.of(context).colorScheme.error.withOpacity(0.5)),
                          ),
                        ),
                      ),
                    ],
                    
                    // Pay Now button for non-admin users who owe money
                    if (!isOwnerOrAdmin && invoice.status == 'SUBMITTED' && userOwes) ...[
                      const SizedBox(height: AppSpacing.md),
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

  Widget _buildTotalCard(BuildContext context, Invoice invoice, bool isDark) {
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  _brand.withOpacity(0.15),
                  AppColors.brandDark.withOpacity(0.10),
                ]
              : [
                  AppColors.brandSurface,
                  _brand.withOpacity(0.08),
                ],
        ),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: _brand.withOpacity(isDark ? 0.25 : 0.18),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                invoice.hasCurrencyConversion ? 'Original Total' : 'Total Amount',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppColors.brandDark,
                ),
              ),
              Text(
                CurrencyFormatter.formatCurrency(invoice.amountTotal, invoice.currency),
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: _brand,
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
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.7),
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
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    if (_currentInvoice == null) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    Color badgeColor;
    Color badgeTextColor;
    Color badgeBgColor;
    String statusText;

    switch (_currentInvoice!.status) {
      case 'DRAFT':
        badgeColor = scheme.outline;
        badgeTextColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
        badgeBgColor = isDark
            ? scheme.surfaceContainerHigh
            : const Color(0xFFF1F5F9);
        statusText = 'Draft';
        break;
      case 'SUBMITTED':
        badgeColor = _brand;
        badgeTextColor = Colors.white;
        badgeBgColor = _brand;
        statusText = 'Submitted';
        break;
      case 'PAID':
        badgeColor = scheme.tertiary;
        badgeTextColor = Colors.white;
        badgeBgColor = scheme.tertiary;
        statusText = 'Paid';
        break;
      case 'LOCKED':
        badgeColor = scheme.tertiary;
        badgeTextColor = Colors.white;
        badgeBgColor = scheme.tertiary;
        statusText = 'Locked';
        break;
      default:
        badgeColor = scheme.outlineVariant;
        badgeTextColor = scheme.onSurfaceVariant;
        badgeBgColor = scheme.surfaceContainerHigh;
        statusText = _currentInvoice!.status;
    }

    // For Draft, use a tonal style; for others, use filled
    final isDraft = _currentInvoice!.status == 'DRAFT';

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: badgeBgColor,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: isDraft
              ? Border.all(color: badgeColor.withOpacity(0.4))
              : null,
        ),
        child: Text(
          statusText.toUpperCase(),
          style: TextStyle(
            color: badgeTextColor,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? _brand.withOpacity(0.12)
                  : _brand.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Icon(icon, color: _brand.withOpacity(0.8), size: 24),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? _brand.withOpacity(0.12)
                      : _brand.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  'ITEM $index',
                  style: textTheme.labelSmall?.copyWith(
                    color: _brand,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
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
                    color: isDark
                        ? _brand.withOpacity(0.08)
                        : _brand.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(
                      color: _brand.withOpacity(isDark ? 0.18 : 0.12),
                    ),
                  ),
                  child: Text(
                    name,
                    style: textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? scheme.onSurface
                          : AppColors.brandDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Share per person: ${CurrencyFormatter.formatCurrency((item.amount / item.assignedTo.length).floorToDouble(), _currentInvoice!.currency)}',
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

  Widget _buildPerPersonBreakdown(BuildContext context, Invoice invoice, bool isDark) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Aggregate each person's total share across all items
    // Rounding rule: debtors get floor(amount/N), uploader absorbs remainder
    final Map<String, double> perPersonTotal = {};
    final Map<String, String> personNames = {};
    final uploaderId = invoice.uploadedBy;

    for (final item in invoice.items) {
      if (item.assignedTo.isEmpty) continue;

      final n = item.assignedTo.length;
      final baseShare = (item.amount / n).floorToDouble();
      final uploaderShare = item.amount - (baseShare * (n - 1));

      for (int i = 0; i < item.assignedTo.length; i++) {
        final uid = item.assignedTo[i];
        final name = i < item.assignedToNames.length
            ? item.assignedToNames[i]
            : uid;
        final share = (uid == uploaderId) ? uploaderShare : baseShare;
        perPersonTotal[uid] = (perPersonTotal[uid] ?? 0) + share;
        personNames[uid] = name;
      }
    }

    if (perPersonTotal.isEmpty) return const SizedBox.shrink();

    final entries = perPersonTotal.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PER-PERSON BREAKDOWN',
          style: textTheme.labelSmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            children: entries.asMap().entries.map((mapEntry) {
              final uid = mapEntry.value.key;
              final amount = mapEntry.value.value;
              final name = personNames[uid] ?? uid;
              final isLast = mapEntry.key == entries.length - 1;

              return Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: isDark
                            ? _brand.withOpacity(0.15)
                            : _brand.withOpacity(0.08),
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _brand,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          name,
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatCurrency(amount, invoice.currency),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: _brand,
                        ),
                      ),
                    ],
                  ),
                  if (!isLast)
                    Divider(
                      height: AppSpacing.lg,
                      color: scheme.outlineVariant.withOpacity(0.3),
                    ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
