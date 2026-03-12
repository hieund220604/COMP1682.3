import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/entities/invoice.dart';
import '../providers/invoice_provider.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'payment_page.dart';

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

  Future<void> _submitInvoice() async {
    if (_currentInvoice == null) return;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Submit Invoice'),
        content: const Text('Are you sure you want to submit this invoice? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.silver)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    final provider = context.read<InvoiceProvider>();
    final success = await provider.submitInvoice(widget.groupId, _currentInvoice!.id);

    setState(() => _isSubmitting = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice submitted successfully')),
      );
      await _loadInvoiceDetail();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to submit invoice'),
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.midnightBlue),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Invoice Details',
            style: TextStyle(
              color: AppColors.midnightBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.background.withOpacity(0.9),
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentInvoice == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.midnightBlue),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Invoice Details',
            style: TextStyle(
              color: AppColors.midnightBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: AppColors.background.withOpacity(0.9),
          elevation: 0,
        ),
        body: const Center(child: Text('Invoice not found')),
      );
    }

    final invoice = _currentInvoice!;
    
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.midnightBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Invoice Details',
          style: TextStyle(
            color: AppColors.midnightBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background.withOpacity(0.9),
        elevation: 0,
        actions: [
          if (invoice.status == 'DRAFT' && context.read<GroupProvider>().isOwnerOrAdmin)
            IconButton(
              icon: const Icon(Icons.edit, color: AppColors.midnightBlue),
              onPressed: () {
                // TODO: Navigate to edit page
              },
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInvoiceDetail,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge
              _buildStatusBadge(),
              const SizedBox(height: 20),

              // Title Card
              _buildInfoCard(
                icon: Icons.receipt_long,
                title: 'Invoice Title',
                content: invoice.title,
              ),
              const SizedBox(height: 16),

              // Note Card
              if (invoice.note?.isNotEmpty ?? false) ...[
                _buildInfoCard(
                  icon: Icons.note,
                  title: 'Note',
                  content: invoice.note!,
                ),
                const SizedBox(height: 16),
              ],

              // Uploaded By Card
              _buildInfoCard(
                icon: Icons.person,
                title: 'Uploaded By',
                content: invoice.uploadedByName,
              ),
              const SizedBox(height: 16),

              // Date Card
              _buildInfoCard(
                icon: Icons.calendar_today,
                title: 'Created Date',
                content: _formatDate(invoice.createdAt),
              ),
              const SizedBox(height: 24),

              // Items Section
              Divider(color: AppColors.silver.withOpacity(0.3)),
              const SizedBox(height: 24),
              Text(
                'INVOICE ITEMS',
                style: TextStyle(
                  color: AppColors.silver,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 16),

              ...invoice.items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildItemCard(index + 1, item);
              }).toList(),

              const SizedBox(height: 24),

              // Total Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          invoice.hasCurrencyConversion ? 'Original Total' : 'Total Amount',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatCurrency(invoice.amountTotal, invoice.currency),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    if (invoice.hasCurrencyConversion) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Converted (${invoice.baseCurrency ?? 'VND'})',
                                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                                ),
                                Text(
                                  CurrencyFormatter.formatCurrency(
                                    invoice.convertedAmountTotal!, invoice.baseCurrency ?? 'VND'),
                                  style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.lock_outline, size: 12, color: Colors.white54),
                                const SizedBox(width: 4),
                                Text(
                                  '1 ${invoice.currency} = ${invoice.exchangeRate!.toStringAsFixed(invoice.exchangeRate! < 1 ? 6 : 2)} ${invoice.baseCurrency ?? 'VND'}',
                                  style: const TextStyle(fontSize: 11, color: Colors.white54),
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
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitInvoice,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'Submit Invoice',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ],
                    
                    // Pay Now button for non-admin users who owe money
                    if (!isOwnerOrAdmin && invoice.status == 'SUBMITTED' && userOwes) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isPayingNow ? null : _handlePayNow,
                          icon: const Icon(Icons.payment),
                          label: _isPayingNow
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Pay Now',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
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

  Widget _buildStatusBadge() {
    if (_currentInvoice == null) return const SizedBox.shrink();
    
    Color badgeColor;
    String statusText;

    switch (_currentInvoice!.status) {
      case 'DRAFT':
        badgeColor = Colors.orange;
        statusText = 'Draft';
        break;
      case 'SUBMITTED':
        badgeColor = Colors.green;
        statusText = 'Submitted';
        break;
      case 'PAID':
        badgeColor = Colors.blue;
        statusText = 'Paid';
        break;
      default:
        badgeColor = Colors.grey;
        statusText = _currentInvoice!.status;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: badgeColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: badgeColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          statusText.toUpperCase(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.silver,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    color: AppColors.midnightBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, InvoiceItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.silver.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ITEM $index',
                style: TextStyle(
                  color: AppColors.silver,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                CurrencyFormatter.formatCurrency(item.amount, _currentInvoice!.currency),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.name,
            style: const TextStyle(
              color: AppColors.midnightBlue,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (item.assignedToNames.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: item.assignedToNames.map<Widget>((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                  ),
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text(
              'Share per person: ${CurrencyFormatter.formatCurrency(item.sharePerPerson, _currentInvoice!.currency)}',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.silver,
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
