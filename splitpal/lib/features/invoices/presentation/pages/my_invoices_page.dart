import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../providers/invoice_provider.dart';
import '../../domain/entities/invoice.dart';
import 'invoice_detail_page.dart';

/// Page showing invoices where current user is assigned to pay
class MyInvoicesPage extends StatefulWidget {
  static const routeName = '/my-invoices';

  const MyInvoicesPage({super.key});

  @override
  State<MyInvoicesPage> createState() => _MyInvoicesPageState();
}

class _MyInvoicesPageState extends State<MyInvoicesPage> {
  String _selectedStatus = 'ALL';
  bool _isLoading = false;
  List<Invoice> _myInvoices = [];
  Map<String, double> _myAmounts = {}; // invoiceId -> amount I need to pay

  @override
  void initState() {
    super.initState();
    // Defer loading until after first frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadMyInvoices();
    });
  }

  Future<void> _loadMyInvoices() async {
    setState(() => _isLoading = true);
    
    try {
      final authProvider = context.read<AuthProvider>();
      final currentUserId = authProvider.user?.id;
      
      if (currentUserId == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get all groups user is member of
      final groupProvider = context.read<GroupProvider>();
      await groupProvider.fetchGroupsAndInvites();
      final groups = groupProvider.groups;

      // Load invoices from all groups
      final invoiceProvider = context.read<InvoiceProvider>();
      List<Invoice> allInvoices = [];
      
      for (final groupData in groups) {
        // Extract group id from map
        final groupId = groupData is Map ? groupData['id'] as String? : null;
        if (groupId == null) continue;
        
        await invoiceProvider.loadInvoices(groupId);
        allInvoices.addAll(invoiceProvider.invoices);
      }

      // Filter invoices where current user is assigned
      final myInvoices = <Invoice>[];
      final myAmounts = <String, double>{};

      for (final invoice in allInvoices) {
        double userTotal = 0;
        bool isAssigned = false;

        for (final item in invoice.items) {
          if (item.assignedTo.contains(currentUserId)) {
            isAssigned = true;
            // Calculate share per person for this item
            final sharePerPerson = item.assignedTo.isNotEmpty 
                ? item.amount / item.assignedTo.length 
                : 0;
            userTotal += sharePerPerson;
          }
        }

        if (isAssigned) {
          myInvoices.add(invoice);
          myAmounts[invoice.id] = userTotal;
        }
      }

      setState(() {
        _myInvoices = myInvoices;
        _myAmounts = myAmounts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load invoices: $e')),
        );
      }
    }
  }

  List<Invoice> _getFilteredInvoices() {
    if (_selectedStatus == 'ALL') return _myInvoices;
    return _myInvoices.where((inv) => inv.status == _selectedStatus).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredInvoices = _getFilteredInvoices();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('My Invoices'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadMyInvoices,
        child: Column(
          children: [
            _buildStatusFilter(),
            if (_isLoading)
              const Expanded(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredInvoices.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 80,
                        color: AppColors.silver,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _selectedStatus == 'ALL'
                            ? 'No invoices assigned to you'
                            : 'No $_selectedStatus invoices',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.silver,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredInvoices.length,
                  itemBuilder: (context, index) {
                    final invoice = filteredInvoices[index];
                    return _buildInvoiceCard(invoice);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilter() {
    final statuses = ['ALL', 'DRAFT', 'SUBMITTED', 'PAID'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.white,
      child: Row(
        children: statuses.map((status) {
          final isSelected = _selectedStatus == status;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(status),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedStatus = status);
                }
              },
              backgroundColor: AppColors.clouds,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.midnightBlue,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInvoiceCard(Invoice invoice) {
    final myAmount = _myAmounts[invoice.id] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          // Navigate to detail page
          await Navigator.pushNamed(
            context,
            InvoiceDetailPage.routeName,
            arguments: {
              'invoiceId': invoice.id,
              'groupId': invoice.groupId,
            },
          );
          // Reload after returning
          _loadMyInvoices();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Uploaded by ${invoice.uploadedByName}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.silver,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusBadge(invoice.status),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.clouds,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your share',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.silver,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatVND(myAmount),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total invoice',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.silver,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.formatVND(invoice.amountTotal),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (invoice.status == 'SUBMITTED')
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Navigate to payment flow
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment flow coming soon'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.payment, size: 18),
                      label: const Text('Pay Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'DRAFT':
        bgColor = AppColors.clouds;
        textColor = AppColors.silver;
        break;
      case 'SUBMITTED':
        bgColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        break;
      case 'PAID':
        bgColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        break;
      default:
        bgColor = AppColors.clouds;
        textColor = AppColors.midnightBlue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
