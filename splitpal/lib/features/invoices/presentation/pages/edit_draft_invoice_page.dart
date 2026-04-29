import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:splitpal/models/invoice.dart';
import 'package:splitpal/features/invoices/bill_template_provider.dart';

/// Edit item amounts in a recurring DRAFT invoice.
/// Owner enters actual amounts (e.g., this month's electricity bill) before confirming.
class EditDraftInvoicePage extends StatefulWidget {
  final String groupId;
  final Invoice invoice;

  const EditDraftInvoicePage({
    Key? key,
    required this.groupId,
    required this.invoice,
  }) : super(key: key);

  @override
  State<EditDraftInvoicePage> createState() => _EditDraftInvoicePageState();
}

class _EditDraftInvoicePageState extends State<EditDraftInvoicePage> {
  late List<_ItemEditState> _itemStates;
  bool _isSaving = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _itemStates = widget.invoice.items.map((item) {
      return _ItemEditState(
        item: item,
        amountController: TextEditingController(
          text: item.amount == 0 ? '' : item.amount.toStringAsFixed(0),
        ),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final s in _itemStates) {
      s.amountController.dispose();
    }
    super.dispose();
  }

  double get _totalAmount =>
      _itemStates.fold(0, (sum, s) => sum + (s.currentAmount ?? 0));

  bool get _hasZeroItems =>
      _itemStates.any((s) => (s.currentAmount ?? 0) <= 0);

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_hasZeroItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter amounts for all items before saving.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final items = _itemStates.map((s) => {
      'name': s.item.name,
      'amount': s.currentAmount ?? 0,
      'splitType': s.item.splitType,
      'assignedTo': s.item.assignedTo,
      if (s.item.splits.isNotEmpty)
        'splits': s.item.splits.map((sp) => {'userId': sp.userId, 'value': sp.value}).toList(),
    }).toList();

    final provider = context.read<BillTemplateProvider>();
    final ok = await provider.updateDraftItems(
      widget.groupId,
      widget.invoice.id,
      title: widget.invoice.title,
      amountTotal: _totalAmount,
      items: items,
      note: widget.invoice.note,
    );

    setState(() => _isSaving = false);

    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Amounts updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Update failed'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE8472A),
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Edit Amounts', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              widget.invoice.title,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_outlined, color: Colors.white),
              label: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Instruction banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(Icons.edit_note, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Enter the actual amount for each item. Items with amount = 0 must be filled in before confirming.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Item list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _itemStates.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final state = _itemStates[index];
                  return _buildItemCard(state, index, scheme);
                },
              ),
            ),

            // Footer total + save button
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.formatVND(_totalAmount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 22,
                          color: const Color(0xFFE8472A),
                        ),
                      ),
                    ],
                  ),
                  if (_hasZeroItems)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${_itemStates.where((s) => (s.currentAmount ?? 0) <= 0).length} items still need amounts',
                            style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Changes',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFE8472A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(_ItemEditState state, int index, ColorScheme scheme) {
    final amount = state.currentAmount ?? 0;
    final isZero = amount <= 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isZero ? Colors.orange.shade300 : Colors.grey.shade200,
          width: isZero ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isZero ? Colors.orange.shade100 : const Color(0xFFFFEDE9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isZero ? Colors.orange.shade700 : const Color(0xFFE8472A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppColors.midnightBlue,
                      ),
                    ),
                    Text(
                      _splitTypeLabel(state.item.splitType),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              if (isZero)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: state.amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            onChanged: (v) {
              setState(() {
                state.currentAmount = double.tryParse(v.replaceAll(',', ''));
              });
            },
            validator: (v) {
              final val = double.tryParse(v?.replaceAll(',', '') ?? '');
              if (val == null || val <= 0) {
                return 'Amount must be greater than 0';
              }
              return null;
            },
            decoration: InputDecoration(
              labelText: 'Amount (VND)',
              hintText: 'Enter actual amount',
              prefixIcon: const Icon(Icons.attach_money, color: const Color(0xFFE8472A)),
              suffixText: '₫',
              filled: true,
              fillColor: isZero ? Colors.orange.shade50 : Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isZero ? Colors.orange.shade300 : Colors.grey.shade300,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(
                  color: isZero ? Colors.orange.shade300 : Colors.grey.shade300,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: const Color(0xFFE8472A), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          // Display assigned members
          if (state.item.assignedToNames.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: state.item.assignedToNames.map<Widget>((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEDE9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    name,
                    style: TextStyle(
                      color: const Color(0xFFC23A20),
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Per-person share preview
          if (amount > 0 && state.item.assignedTo.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.calculate_outlined, size: 14, color: Colors.green.shade700),
                  const SizedBox(width: 4),
                  Text(
                    'Per person: ${CurrencyFormatter.formatVND(amount / state.item.assignedTo.length)}',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _splitTypeLabel(String splitType) {
    switch (splitType) {
      case 'EQUAL': return 'Equal split';
      case 'PERCENTAGE': return 'By percentage';
      case 'CUSTOM': return 'Custom';
      case 'WEIGHT': return 'By weight';
      default: return splitType;
    }
  }
}

class _ItemEditState {
  final InvoiceItem item;
  final TextEditingController amountController;
  double? currentAmount;

  _ItemEditState({
    required this.item,
    required this.amountController,
  }) {
    currentAmount = item.amount > 0 ? item.amount : null;
  }
}
