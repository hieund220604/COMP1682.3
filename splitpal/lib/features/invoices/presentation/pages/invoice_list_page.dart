import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../providers/invoice_provider.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import 'create_invoice_page.dart';
import 'invoice_capture_mode_page.dart';
import 'invoice_detail_page.dart';

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

class _InvoiceListPageState extends State<InvoiceListPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvoices();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInvoices() async {
    final provider = context.read<InvoiceProvider>();
    
    // Load based on current tab
    String? status;
    if (_tabController.index == 1) {
      status = 'DRAFT';
    } else if (_tabController.index == 2) {
      status = 'SUBMITTED';
    } else if (_tabController.index == 3) {
      status = 'LOCKED';
    }
    
    await provider.loadInvoices(widget.groupId, status: status);
    await provider.loadMyBalance(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        bottom: TabBar(
          controller: _tabController,
          onTap: (index) {
            _loadInvoices();
          },
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Draft'),
            Tab(text: 'Submitted'),
            Tab(text: 'Locked'),
          ],
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
              // Invoice List
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _loadInvoices,
                  child: provider.invoices.isEmpty
                      ? const Center(
                          child: Text('No invoices yet'),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: provider.invoices.length,
                          itemBuilder: (context, index) {
                            final invoice = provider.invoices[index];
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
                                title: Text(invoice.title),
                                subtitle: Text(
                                  '${invoice.items.length} items • ${invoice.status}',
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
                        ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<GroupProvider>(
        builder: (context, groupProvider, child) {
          // Only show create invoice button for admin/owner
          if (!groupProvider.isOwnerOrAdmin) {
            return const SizedBox.shrink();
          }
          
          return FloatingActionButton.extended(
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
            label: const Text('New Invoice'),
          );
        },
      ),
    );
  }

  Widget _buildBalanceItem(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.formatVND(amount),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'DRAFT':
        return Colors.grey;
      case 'SUBMITTED':
        return Colors.blue;
      case 'PAID':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
