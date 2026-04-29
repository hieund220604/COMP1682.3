import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:splitpal/models/invoice.dart';
import 'package:splitpal/features/ai/ai_provider.dart';
import 'package:splitpal/features/invoices/invoice_provider.dart';
import 'package:splitpal/features/ai/presentation/widgets/invoice_ocr_picker.dart';
import 'package:splitpal/features/groups/group_provider.dart';
import 'package:splitpal/features/auth/auth_provider.dart';
import 'package:splitpal/core/app_services.dart';

class CreateInvoicePage extends StatefulWidget {
  final String groupId;
  final String? prefillTitle;
  final String? prefillNote;
  final double? prefillAmount;
  final String? prefillCurrency;
  final Map<String, dynamic>? prefillAiData;

  const CreateInvoicePage({
    Key? key,
    required this.groupId,
    this.prefillTitle,
    this.prefillNote,
    this.prefillAmount,
    this.prefillCurrency,
    this.prefillAiData,
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
  static const _supportedSplitTypes = ['EQUAL', 'PERCENTAGE', 'CUSTOM'];

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroupMembers();
    });
    _addNewItem();
    _applyPrefill();
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

      if (!mounted) return;

      final group = groupProvider.currentGroup;
      final baseCurrency = (group?['baseCurrency'] ?? group?['currency'] ?? 'VND').toString();
      
      setState(() {
        _groupBaseCurrency = baseCurrency;
        _selectedCurrency = widget.prefillCurrency?.isNotEmpty == true
            ? widget.prefillCurrency!
            : baseCurrency;
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
        
        if (widget.prefillAiData != null && widget.prefillAiData!['items'] != null) {
            _applyAiData(widget.prefillAiData!);
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMembers = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load members: $e')),
      );
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

  void _applyPrefill() {
    if (widget.prefillTitle != null && widget.prefillTitle!.isNotEmpty) {
      _titleController.text = widget.prefillTitle!;
    }
    if (widget.prefillNote != null && widget.prefillNote!.isNotEmpty) {
      _noteController.text = widget.prefillNote!;
    }
    if (widget.prefillCurrency != null && widget.prefillCurrency!.isNotEmpty) {
      _selectedCurrency = widget.prefillCurrency!;
    }
    if (_items.isNotEmpty && widget.prefillAmount != null && widget.prefillAiData == null) {
      _items.first.amountController.text =
          widget.prefillAmount!.toStringAsFixed(2);
    }
    if (_items.isNotEmpty && widget.prefillTitle != null && widget.prefillTitle!.isNotEmpty && widget.prefillAiData == null) {
      _items.first.nameController.text = widget.prefillTitle!;
    }
  }

  String? _findUserId(String nameText) {
    final lowerInput = nameText.toLowerCase().trim();
    // First-person pronouns → current user
    if (lowerInput == 'người gửi' || lowerInput == 'tôi' || lowerInput == 'mình' || lowerInput == 'me') {
      final currentUserId = context.read<AuthProvider>().user?.id ?? AppServices.tokenManager.getUserId();
      if (currentUserId != null) return currentUserId;
    }
    // Strip Vietnamese title prefixes before matching
    final stripped = lowerInput
        .replaceAll(RegExp(r'\b(anh|chị|chi|em|bạn|ban|mr|ms|ông|ong|bà|ba)\b'), '')
        .trim();
    final toSearch = stripped.isNotEmpty ? stripped : lowerInput;

    // 1. Exact match
    for (var member in _groupMembers) {
      final mName = (member['name'] as String).toLowerCase();
      if (mName == toSearch) return member['id'] as String;
    }
    // 2. Partial match (both directions)
    for (var member in _groupMembers) {
      final mName = (member['name'] as String).toLowerCase();
      if (mName.contains(toSearch) || toSearch.contains(mName)) {
        return member['id'] as String;
      }
    }
    return null;
  }

  void _applyAiData(Map<String, dynamic> data) {
    // Guard: if members not loaded yet, skip (will be called again after load)
    if (_isLoadingMembers) return;

    final rawItems = data['items'] as List<dynamic>? ?? [];
    final rootSplitDetails = data['splitDetails'] as Map<String, dynamic>? ?? {};

    // Normalize splitMethod to a canonical uppercase form
    final rawMethod = (data['splitMethod'] as String? ?? 'unknown').toLowerCase().trim();
    final rootSplitMethod = switch (rawMethod) {
      'equal'         => 'EQUAL',
      'percentage'    => 'PERCENTAGE',
      'shares'        => 'SHARES',
      'custom_amount' => 'CUSTOM_AMOUNT',
      _               => 'EQUAL', // 'unknown' or anything else → equal
    };

    // Map AI canonical method → UI splitType enum (EQUAL | PERCENTAGE | CUSTOM)
    String toUiSplitType(String sm) {
      if (sm == 'CUSTOM_AMOUNT') return 'CUSTOM';
      if (sm == 'PERCENTAGE' || sm == 'SHARES') return 'PERCENTAGE';
      return 'EQUAL';
    }

    // Clear initial blank item created in initState
    if (_items.length == 1 && _items.first.nameController.text.isEmpty) {
      _items.first.dispose();
      _items.clear();
    }

    // Fallback: no items but has a total amount → create one generic item
    if (rawItems.isEmpty && data['amountTotal'] != null) {
      final amount = data['amountTotal'] is num ? (data['amountTotal'] as num).toDouble() : 0.0;
      final senderUid = _findUserId('me');
      final newItem = InvoiceItemData(
        nameController: TextEditingController(
            text: _titleController.text.isNotEmpty ? _titleController.text : 'Ghi chú hóa đơn'),
        amountController: TextEditingController(text: amount.toStringAsFixed(2)),
        splitType: 'EQUAL',
        assignedTo: senderUid != null
            ? [senderUid]
            : (_groupMembers.isNotEmpty ? [_groupMembers[0]['id'] as String] : []),
      );
      _items.add(newItem);
      return;
    }

    for (var raw in rawItems) {
      final name = raw['name'] ?? 'Item';
      final itemAmount = raw['amount'] is num ? (raw['amount'] as num).toDouble() : 0.0;
      final assigneesList = raw['assignees'] as List<dynamic>? ?? [];
      final shared = raw['shared'] == true;

      final newItem = InvoiceItemData(
        nameController: TextEditingController(text: name),
        amountController: TextEditingController(text: itemAmount.toStringAsFixed(2)),
        splitType: toUiSplitType(rootSplitMethod),
        assignedTo: [],
      );

      bool hasAssignedSpecifics = false;

      // --- Apply per-person split values based on canonical method ---
      if (rootSplitMethod == 'CUSTOM_AMOUNT') {
        final customList = rootSplitDetails['customAmounts'] as List<dynamic>? ?? [];
        for (var customObj in customList) {
          final amountVal = customObj['amount'] is num ? (customObj['amount'] as num).toDouble() : 0.0;
          final uid = _findUserId((customObj['name'] as String? ?? ''));
          if (uid != null && !newItem.assignedTo.contains(uid)) {
            newItem.assignedTo.add(uid);
            newItem.splitControllers[uid] = TextEditingController(text: amountVal.toStringAsFixed(2));
            hasAssignedSpecifics = true;
          }
        }
      } else if (rootSplitMethod == 'PERCENTAGE') {
        final percentList = rootSplitDetails['percentages'] as List<dynamic>? ?? [];
        for (var pObj in percentList) {
          final percentVal = pObj['percentage'] is num ? (pObj['percentage'] as num).toDouble() : 0.0;
          final uid = _findUserId((pObj['name'] as String? ?? ''));
          if (uid != null && !newItem.assignedTo.contains(uid)) {
            newItem.assignedTo.add(uid);
            newItem.splitControllers[uid] = TextEditingController(text: percentVal.toStringAsFixed(2));
            hasAssignedSpecifics = true;
          }
        }
      } else if (rootSplitMethod == 'SHARES') {
        // Convert share ratios to percentages so the UI PERCENTAGE mode displays them correctly
        final shareList = rootSplitDetails['shares'] as List<dynamic>? ?? [];
        final totalShares = shareList.fold<double>(
          0.0, (sum, s) => sum + (s['share'] is num ? (s['share'] as num).toDouble() : 0.0));
        if (totalShares > 0) {
          for (var sObj in shareList) {
            final shareVal = sObj['share'] is num ? (sObj['share'] as num).toDouble() : 0.0;
            final uid = _findUserId((sObj['name'] as String? ?? ''));
            if (uid != null && !newItem.assignedTo.contains(uid)) {
              final pct = ((shareVal / totalShares) * 100).toStringAsFixed(2);
              newItem.assignedTo.add(uid);
              newItem.splitControllers[uid] = TextEditingController(text: pct);
              hasAssignedSpecifics = true;
            }
          }
        }
      }

      // Fallback 1: use per-item assignee list from AI (names only, no amounts)
      if (!hasAssignedSpecifics && assigneesList.isNotEmpty) {
        for (var pName in assigneesList) {
          final uid = _findUserId(pName.toString());
          if (uid != null && !newItem.assignedTo.contains(uid)) {
            newItem.assignedTo.add(uid);
            hasAssignedSpecifics = true;
          }
        }
      }

      // Fallback 2: shared item → assign to all group members
      if (!hasAssignedSpecifics && shared) {
        newItem.assignedTo.addAll(_groupMembers.map((e) => e['id'] as String));
        hasAssignedSpecifics = true;
      }

      // Fallback 3: still nobody → assign to current user (or first member)
      if (newItem.assignedTo.isEmpty && _groupMembers.isNotEmpty) {
        final senderUid = _findUserId('me');
        newItem.assignedTo.add(senderUid ?? _groupMembers[0]['id'] as String);
      }

      _items.add(newItem);
    }
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
      final splitType = _normalizeSplitType(item.splitType);
      List<InvoiceItemSplitCreate> splits = [];
      if (splitType != 'EQUAL') {
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
        splitType: splitType,
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
      if (ocrData.title.trim().isNotEmpty) {
        _titleController.text = ocrData.title;
      }

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
          final amount = ocrItem.amount > 0
              ? ocrItem.amount
              : (ocrItem.unitPrice * ocrItem.quantity);

          final newItem = InvoiceItemData(
            nameController: TextEditingController(
              text: ocrItem.name.trim().isNotEmpty ? ocrItem.name : 'Scanned item',
            ),
            amountController: TextEditingController(
              text: amount.toStringAsFixed(2),
            ),
            splitType: 'EQUAL',
            assignedTo: _groupMembers.isNotEmpty
                ? [_groupMembers[0]['id']]
                : [],
          );
          _items.add(newItem);
        }
      } else if (ocrData.amountTotal > 0) {
        // Fallback: model found total but not line items.
        _items.add(
          InvoiceItemData(
            nameController: TextEditingController(text: 'Scanned item'),
            amountController: TextEditingController(
              text: ocrData.amountTotal.toStringAsFixed(2),
            ),
            splitType: 'EQUAL',
            assignedTo: _groupMembers.isNotEmpty
                ? [_groupMembers[0]['id']]
                : [],
          ),
        );
      } else {
        // Keep one editable empty line if no amount/item could be extracted.
        _items.add(
          InvoiceItemData(
            nameController: TextEditingController(),
            amountController: TextEditingController(),
            splitType: 'EQUAL',
            assignedTo: const [],
          ),
        );
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoadingMembers) {
      return Scaffold(
        backgroundColor: scheme.surface,
        appBar: AppBar(
          leading: IconButton(
            icon: Icon(Icons.close, color: scheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Create Invoice',
            style: TextStyle(
              color: scheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: scheme.surface,
          elevation: 0,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.close, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Invoice',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: scheme.surface,
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
                    : Text(
                        'Save',
                        style: TextStyle(
                          color: scheme.primary,
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
                  color: scheme.surfaceContainerHighest,
                  border: Border.all(
                    color: scheme.primary.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      color: scheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        'Tip: Use the camera button to capture & auto-fill invoice details',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.primary,
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
                  Text(
                    'Invoice Details',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.receipt_long, color: scheme.outline),
                ],
              ),
              const SizedBox(height: 24),

              // Title Input
              _buildLabel('Invoice Title', true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.title, color: scheme.outline),
                  hintText: 'Enter invoice title',
                  hintStyle: TextStyle(color: scheme.outline),
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: TextStyle(color: scheme.onSurface),
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
                  prefixIcon: Icon(Icons.note, color: scheme.outline),
                  hintText: 'Add optional note',
                  hintStyle: TextStyle(color: scheme.outline),
                  filled: true,
                  fillColor: scheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: scheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    borderSide: BorderSide(color: scheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
                style: TextStyle(color: scheme.onSurface),
                maxLines: 3,
              ),
              const SizedBox(height: 20),

              // Currency Selector
              _buildLabel('Currency', true),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  border: Border.all(color: scheme.outlineVariant),
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
                      style: TextStyle(color: scheme.onSurface),
                    ),
                  )).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedCurrency = val);
                  },
                  dropdownColor: scheme.surface,
                  style: TextStyle(color: scheme.onSurface, fontSize: 16),
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
              Divider(color: scheme.outlineVariant),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'INVOICE ITEMS',
                    style: TextStyle(
                      color: scheme.outline,
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
                      foregroundColor: scheme.primary,
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
                        Icon(Icons.inventory_2_outlined, size: 48, color: scheme.outline),
                        const SizedBox(height: 12),
                        Text(
                          'No items yet',
                          style: TextStyle(color: scheme.outline, fontSize: 14),
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
                    colors: [scheme.primary, scheme.primary.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withOpacity(0.3),
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

  Widget _buildLabel(String text, bool required) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          text.toUpperCase(),
          style: TextStyle(
            color: scheme.outline,
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
    final scheme = Theme.of(context).colorScheme;
    final activeSplitType = _normalizeSplitType(item.splitType);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
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
                  color: scheme.outline,
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
              prefixIcon: Icon(Icons.shopping_bag_outlined, color: scheme.outline),
              hintText: 'Enter item name',
              hintStyle: TextStyle(color: scheme.outline),
              filled: true,
              fillColor: scheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(color: scheme.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: TextStyle(color: scheme.onSurface),
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
                    Icon(Icons.attach_money, color: scheme.outline, size: 20),
                    Text(
                      _selectedCurrency,
                      style: TextStyle(
                        color: scheme.outline,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              hintText: '0',
              hintStyle: TextStyle(color: scheme.outline),
              filled: true,
              fillColor: scheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.md),
                borderSide: BorderSide(color: scheme.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
            ),
            style: TextStyle(
              color: scheme.onSurface,
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
                    color: isSelected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
                selectedColor: scheme.primary,
                checkmarkColor: scheme.onPrimary,
                backgroundColor: scheme.surface,
                side: BorderSide(
                  color: isSelected ? scheme.primary : scheme.outlineVariant,
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
                  color: scheme.outline,
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
            children: _supportedSplitTypes.map((type) {
              final selected = activeSplitType == type;
              return ChoiceChip(
                label: Text(
                  _splitTypeLabel(type),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: selected ? scheme.onPrimary : scheme.onSurface,
                  ),
                ),
                selected: selected,
                selectedColor: scheme.primary,
                backgroundColor: scheme.surface,
                side: BorderSide(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                onSelected: (_) => setState(() => item.splitType = type),
              );
            }).toList(),
          ),

          // Per-user split inputs (only for non-EQUAL modes)
          if (activeSplitType != 'EQUAL' && item.assignedTo.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildLabel(_splitTypeHint(activeSplitType), false),
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
                        style: TextStyle(
                          color: scheme.onSurface,
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
                          hintText: '0',
                          hintStyle: TextStyle(color: scheme.outline),
                          suffix: activeSplitType == 'PERCENTAGE'
                              ? Text('%', style: TextStyle(color: scheme.onSurface))
                              : null,
                          filled: true,
                          fillColor: scheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            borderSide: BorderSide(color: scheme.outlineVariant),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            borderSide: BorderSide(color: scheme.outlineVariant),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadii.md),
                            borderSide: BorderSide(color: scheme.primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        style: TextStyle(color: scheme.onSurface),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            // Live validation hint
            Builder(builder: (_) {
              final hint = _computeSplitValidationHint(item, activeSplitType);
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
      default: return type;
    }
  }

  String _splitTypeHint(String type) {
    switch (type) {
      case 'PERCENTAGE': return 'Percentage per person (total must = 100%)';
      case 'CUSTOM': return 'Exact amount per person';
      default: return '';
    }
  }

  String _normalizeSplitType(String type) {
    if (_supportedSplitTypes.contains(type)) {
      return type;
    }
    return 'EQUAL';
  }

  /// Returns a live hint string for PERCENTAGE/CUSTOM splits, null otherwise.
  String? _computeSplitValidationHint(InvoiceItemData item, String splitType) {
    if (splitType == 'PERCENTAGE') {
      final total = item.assignedTo.fold<double>(0, (sum, uid) {
        final c = item.splitControllers[uid];
        return sum + (double.tryParse(c?.text.trim() ?? '') ?? 0);
      });
      if ((total - 100).abs() < 0.01) return '✓ Total: ${total.toStringAsFixed(1)}%';
      return 'Total: ${total.toStringAsFixed(1)}% (must equal 100%)';
    }
    if (splitType == 'CUSTOM') {
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
