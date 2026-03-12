import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../../domain/services/gemini_ocr_service.dart';
import '../providers/invoice_provider.dart';
import '../providers/ocr_provider.dart';
import '../widgets/invoice_ocr_picker.dart';
import '../../../groups/presentation/providers/group_provider.dart';

class CreateInvoicePage extends StatefulWidget {
  final String groupId;

  const CreateInvoicePage({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  State<CreateInvoicePage> createState() => _CreateInvoicePageState();
}

class _CreateInvoicePageState extends State<CreateInvoicePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  
  final List<InvoiceItemData> _items = [];
  List<Map<String, dynamic>> _groupMembers = [];
  bool _isLoadingMembers = true;

  String _selectedCurrency = 'VND';
  String _groupBaseCurrency = 'VND';

  static const _supportedCurrencies = [
    'VND', 'USD', 'EUR', 'GBP', 'JPY', 'KRW', 'CNY', 'THB',
    'SGD', 'AUD', 'CAD', 'CHF', 'HKD', 'INR', 'MYR', 'PHP',
    'TWD', 'NZD', 'SEK',
  ];

  static const _currencyFlags = {
    'VND': '🇻🇳', 'USD': '🇺🇸', 'EUR': '🇪🇺', 'GBP': '🇬🇧',
    'JPY': '🇯🇵', 'KRW': '🇰🇷', 'CNY': '🇨🇳', 'THB': '🇹🇭',
    'SGD': '🇸🇬', 'AUD': '🇦🇺', 'CAD': '🇨🇦', 'CHF': '🇨🇭',
    'HKD': '🇭🇰', 'INR': '🇮🇳', 'MYR': '🇲🇾', 'PHP': '🇵🇭',
    'TWD': '🇹🇼', 'NZD': '🇳🇿', 'SEK': '🇸🇪',
  };
  
  @override
  void initState() {
    super.initState();
    _loadGroupMembers();
    _addNewItem();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> _loadGroupMembers() async {
    try {
      final groupProvider = context.read<GroupProvider>();
      await groupProvider.fetchGroupDetailsData(widget.groupId);

      final group = groupProvider.currentGroup;
      final baseCurrency = (group?['baseCurrency'] ?? group?['currency'] ?? 'VND').toString();
      
      setState(() {
        _groupBaseCurrency = baseCurrency;
        _selectedCurrency = baseCurrency;
        _groupMembers = groupProvider.currentGroupMembers.map((member) {
          // Backend returns: { userId, user: { id, displayName, email, avatarUrl } }
          final user = member['user'];
          return {
            'id': member['userId'] ?? member['_id'] ?? '',
            'name': user != null 
                ? (user['displayName'] ?? user['email'] ?? 'Unknown')
                : (member['name'] ?? 'Unknown'),
          };
        }).toList();
        _isLoadingMembers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMembers = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load members: $e')),
        );
      }
    }
  }

  void _addNewItem() {
    setState(() {
      _items.add(InvoiceItemData(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
        assignedTo: [],
        splitType: 'EQUAL',
      ));
    });
  }

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  double _calculateTotal() {
    return _items.fold(0.0, (sum, item) {
      final amount = double.tryParse(item.amountController.text) ?? 0.0;
      return sum + amount;
    });
  }

  Future<void> _createInvoice() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one item')),
      );
      return;
    }

    final items = _items.map((item) {
      List<InvoiceItemSplitCreate> splits = [];
      if (item.splitType != 'EQUAL') {
        splits = item.assignedTo.map((userId) {
          final controller = item.splitControllers[userId];
          return InvoiceItemSplitCreate(
            userId: userId,
            value: double.tryParse(controller?.text.trim() ?? '0') ?? 0.0,
          );
        }).toList();
      }
      return InvoiceItemCreate(
        name: item.nameController.text,
        amount: double.parse(item.amountController.text),
        splitType: item.splitType,
        assignedTo: item.assignedTo,
        splits: splits,
      );
    }).toList();

    final provider = context.read<InvoiceProvider>();
    final success = await provider.createInvoice(
      groupId: widget.groupId,
      title: _titleController.text,
      amountTotal: _calculateTotal(),
      items: items,
      note: _noteController.text.isEmpty ? null : _noteController.text,
      currency: _selectedCurrency,
    );

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invoice created successfully')),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to create invoice'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showOcrPicker() {
    InvoiceOcrPicker.showOcrBottomSheet(
      context,
      onDataExtracted: _handleOcrConfirm,
    );
  }

  void _handleOcrConfirm(InvoiceOcrData ocrData) {
    // Populate form with OCR extracted data
    setState(() {
      // Title
      _titleController.text = ocrData.title;

      // Currency
      if (_supportedCurrencies.contains(ocrData.currency)) {
        _selectedCurrency = ocrData.currency;
      }

      // Note
      if (ocrData.note != null) {
        _noteController.text = ocrData.note!;
      }

      // Clear existing items and populate with OCR items
      for (var item in _items) {
        item.dispose();
      }
      _items.clear();

      if (ocrData.items.isNotEmpty) {
        for (var ocrItem in ocrData.items) {
          final newItem = InvoiceItemData(
            nameController: TextEditingController(text: ocrItem.name),
            amountController: TextEditingController(
              text: ocrItem.amount.toStringAsFixed(2),
            ),
            splitType: 'EQUAL',
            assignedTo: _groupMembers.isNotEmpty
                ? [_groupMembers[0]['id']]
                : [],
          );
          _items.add(newItem);
        }
      } else {
        // Add empty item if OCR didn't extract items
        _addNewItem();
      }
    });

    // Show success snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invoice data loaded. Please review and edit if needed.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMembers) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close, color: AppColors.midnightBlue),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Create Invoice',
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.midnightBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Invoice',
          style: TextStyle(
            color: AppColors.midnightBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: AppColors.background.withOpacity(0.9),
        elevation: 0,
        actions: [
          // OCR Camera Button
          IconButton(
            icon: const Icon(Icons.camera_alt, color: AppColors.primary),
            tooltip: 'Capture invoice',
            onPressed: _showOcrPicker,
          ),
          // Save Button
          Consumer<InvoiceProvider>(
            builder: (context, provider, child) {
              return TextButton(
                onPressed: provider.isLoading ? null : _createInvoice,
                child: provider.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                        ),
                      )
                    : const Text(
                        'Save',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // OCR Info Banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: Use the camera button to capture & auto-fill invoice details',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Invoice Details',
                    style: TextStyle(
                      color: AppColors.midnightBlue,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.receipt_long, color: AppColors.silver),
                ],
              ),
              const SizedBox(height: 24),

              // Title Input
              _buildLabel('Invoice Title', true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.title, color: AppColors.silver),
                  hintText: 'Enter invoice title',
                  hintStyle: TextStyle(color: AppColors.silver),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.silver.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.silver.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: const TextStyle(color: AppColors.midnightBlue),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Note Input
              _buildLabel('Note', false),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.note, color: AppColors.silver),
                  hintText: 'Add optional note',
                  hintStyle: TextStyle(color: AppColors.silver),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.silver.withOpacity(0.3)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.silver.withOpacity(0.3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: const TextStyle(color: AppColors.midnightBlue),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Currency Selector
              _buildLabel('Currency', true),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.silver.withOpacity(0.3)),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedCurrency,
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Text(
                        _currencyFlags[_selectedCurrency] ?? '💱',
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 48),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  items: _supportedCurrencies.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(
                      '${_currencyFlags[c] ?? '💱'} $c',
                      style: const TextStyle(color: AppColors.midnightBlue),
                    ),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCurrency = val);
                  },
                  dropdownColor: Colors.white,
                  style: const TextStyle(color: AppColors.midnightBlue, fontSize: 16),
                ),
              ),
              if (_selectedCurrency != _groupBaseCurrency)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 14, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Exchange rate to $_groupBaseCurrency will be locked when this invoice is created.',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 32),

              // Items Section Header
              Divider(color: AppColors.silver.withOpacity(0.3)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'INVOICE ITEMS',
                    style: TextStyle(
                      color: AppColors.silver,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _addNewItem,
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    label: const Text('Add Item'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Items List
              ..._items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return _buildItemCard(index, item);
              }).toList(),

              if (_items.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 48, color: AppColors.silver),
                        const SizedBox(height: 12),
                        Text(
                          'No items yet',
                          style: TextStyle(color: AppColors.silver, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),

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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatCurrency(_calculateTotal(), _selectedCurrency),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool required) {    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            color: AppColors.silver,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        if (required)
          const Text(
            ' *',
            style: TextStyle(
              color: Colors.red,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }

  Widget _buildItemCard(int index, InvoiceItemData item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with delete button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ITEM ${index + 1}',
                style: TextStyle(
                  color: AppColors.silver,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: Colors.red[400], size: 20),
                onPressed: () => _removeItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Item Name
          _buildLabel('Item Name', true),
          const SizedBox(height: 8),
          TextFormField(
            controller: item.nameController,
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.shopping_bag_outlined, color: AppColors.silver),
              hintText: 'Enter item name',
              hintStyle: TextStyle(color: AppColors.silver),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: const TextStyle(color: AppColors.midnightBlue),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter item name';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Item Amount
          _buildLabel('Amount ($_selectedCurrency)', true),
          const SizedBox(height: 8),
          TextFormField(
            controller: item.amountController,
            decoration: InputDecoration(
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.attach_money, color: AppColors.silver, size: 20),
                    Text(
                      _selectedCurrency,
                      style: TextStyle(
                        color: AppColors.silver,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              hintText: '0',
              hintStyle: TextStyle(color: AppColors.silver),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: const TextStyle(
              color: AppColors.midnightBlue,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
            keyboardType: TextInputType.number,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter amount';
              }
              if (double.tryParse(value) == null) {
                return 'Please enter a valid number';
              }
              return null;
            },
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),

          // Assigned To
          _buildLabel('Assigned To', false),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _groupMembers.map((member) {
              final isSelected = item.assignedTo.contains(member['id']);
              return FilterChip(
                selected: isSelected,
                label: Text(
                  member['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.midnightBlue,
                  ),
                ),
                selectedColor: AppColors.primary,
                checkmarkColor: Colors.white,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? AppColors.primary : AppColors.silver.withOpacity(0.3),
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      item.assignedTo.add(member['id']);
                      // Ensure a controller exists when user is added
                      item.splitControllers.putIfAbsent(
                        member['id'] as String,
                        () => TextEditingController(),
                      );
                    } else {
                      item.assignedTo.remove(member['id']);
                    }
                  });
                },
              );
            }).toList(),
          ),
          if (item.assignedTo.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Select at least one member',
                style: TextStyle(
                  color: AppColors.silver,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // Split Method selector
          _buildLabel('Split Method', false),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['EQUAL', 'PERCENTAGE', 'CUSTOM', 'WEIGHT'].map((type) {
              final selected = item.splitType == type;
              return ChoiceChip(
                label: Text(
                  _splitTypeLabel(type),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? Colors.white : AppColors.midnightBlue,
                  ),
                ),
                selected: selected,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected ? AppColors.primary : AppColors.silver.withOpacity(0.3),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                onSelected: (_) => setState(() => item.splitType = type),
              );
            }).toList(),
          ),

          // Per-user split inputs (only for non-EQUAL modes)
          if (item.splitType != 'EQUAL' && item.assignedTo.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildLabel(_splitTypeHint(item.splitType), false),
            const SizedBox(height: 10),
            ...item.assignedTo.map((userId) {
              final memberName = (_groupMembers.firstWhere(
                (m) => m['id'] == userId,
                orElse: () => {'name': 'Unknown'},
              )['name'] ?? 'Unknown') as String;
              // Ensure controller exists
              item.splitControllers.putIfAbsent(userId, () => TextEditingController());
              final controller = item.splitControllers[userId]!;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        memberName,
                        style: const TextStyle(
                          color: AppColors.midnightBlue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: controller,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          hintText: item.splitType == 'WEIGHT' ? '1' : '0',
                          hintStyle: TextStyle(color: AppColors.silver),
                          suffix: item.splitType == 'PERCENTAGE'
                              ? const Text('%', style: TextStyle(color: AppColors.midnightBlue))
                              : null,
                          filled: true,
                          fillColor: AppColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: const TextStyle(color: AppColors.midnightBlue),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            // Live validation hint
            Builder(builder: (_) {
              final hint = _computeSplitValidationHint(item);
              if (hint == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  hint,
                  style: TextStyle(
                    color: hint.startsWith('✓') ? Colors.green[700] : Colors.orange[700],
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _splitTypeLabel(String type) {
    switch (type) {
      case 'EQUAL': return 'Equal';
      case 'PERCENTAGE': return 'Percentage';
      case 'CUSTOM': return 'Custom Amount';
      case 'WEIGHT': return 'Shares';
      default: return type;
    }
  }

  String _splitTypeHint(String type) {
    switch (type) {
      case 'PERCENTAGE': return 'Percentage per person (total must = 100%)';
      case 'CUSTOM': return 'Exact amount per person';
      case 'WEIGHT': return 'Shares per person (proportional split)';
      default: return '';
    }
  }

  /// Returns a live hint string for PERCENTAGE/CUSTOM splits, null for WEIGHT/EQUAL.
  String? _computeSplitValidationHint(InvoiceItemData item) {
    if (item.splitType == 'PERCENTAGE') {
      final total = item.assignedTo.fold<double>(0, (sum, uid) {
        final c = item.splitControllers[uid];
        return sum + (double.tryParse(c?.text.trim() ?? '') ?? 0);
      });
      if ((total - 100).abs() < 0.01) return '✓ Total: ${total.toStringAsFixed(1)}%';
      return 'Total: ${total.toStringAsFixed(1)}% (must equal 100%)';
    }
    if (item.splitType == 'CUSTOM') {
      final itemAmount = double.tryParse(item.amountController.text.trim()) ?? 0;
      final total = item.assignedTo.fold<double>(0, (sum, uid) {
        final c = item.splitControllers[uid];
        return sum + (double.tryParse(c?.text.trim() ?? '') ?? 0);
      });
      if ((total - itemAmount).abs() < 0.01) return '✓ Total: $total (matches item amount)';
      return 'Total: $total (must equal $itemAmount)';
    }
    return null;
  }
}

class InvoiceItemData {
  final TextEditingController nameController;
  final TextEditingController amountController;
  String splitType;
  final List<String> assignedTo;
  /// Controllers for per-user split values (keyed by userId).
  final Map<String, TextEditingController> splitControllers;

  InvoiceItemData({
    required this.nameController,
    required this.amountController,
    this.splitType = 'EQUAL',
    required this.assignedTo,
    Map<String, TextEditingController>? splitControllers,
  }) : splitControllers = splitControllers ?? {};

  void dispose() {
    nameController.dispose();
    amountController.dispose();
    for (final c in splitControllers.values) {
      c.dispose();
    }
  }
}
