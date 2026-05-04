import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:splitpal/models/invoice.dart';
import 'package:splitpal/features/invoices/invoice_provider.dart';

/// Edit item amounts on a DRAFT invoice (both manual and recurring).
/// Owner enters actual amounts before confirming.
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
        SnackBar(
          content: const Text('Please enter amounts for all items before saving.'),
          backgroundColor: Theme.of(context).colorScheme.error,
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

    final provider = context.read<InvoiceProvider>();
    final ok = await provider.updateInvoice(
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
          backgroundColor: AppColors.brandDark,
        ),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Update failed'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Invoice',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
            ),
            Text(
              widget.invoice.title,
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        centerTitle: false,
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            TextButton(
              onPressed: _save,
              child: Text(
                'Save',
                style: TextStyle(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              color: isDark
                  ? AppColors.brand.withValues(alpha: 0.08)
                  : AppColors.brandSurface,
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.brand,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Enter the actual amount for each item before confirming.',
                      style: textTheme.bodySmall?.copyWith(
                        color: isDark
                            ? AppColors.brand.withValues(alpha: 0.85)
                            : AppColors.brandDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Item list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: _itemStates.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final state = _itemStates[index];
                  return _buildItemCard(state, index, scheme, textTheme, isDark);
                },
              ),
            ),

            // Footer total + save button
            _buildFooter(scheme, textTheme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter(ColorScheme scheme, TextTheme textTheme, bool isDark) {
    final zeroCount = _itemStates.where((s) => (s.currentAmount ?? 0) <= 0).length;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xl,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  CurrencyFormatter.formatVND(_totalAmount),
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
            if (_hasZeroItems)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: scheme.error,
                      size: 15,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '$zeroCount item${zeroCount > 1 ? 's' : ''} still need amounts',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isSaving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.5),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(
    _ItemEditState state,
    int index,
    ColorScheme scheme,
    TextTheme textTheme,
    bool isDark,
  ) {
    final amount = state.currentAmount ?? 0;
    final isZero = amount <= 0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(
          color: isZero
              ? scheme.error.withValues(alpha: 0.4)
              : scheme.outlineVariant,
          width: isZero ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header
          Row(
            children: [
              // Index badge
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isZero
                      ? scheme.errorContainer
                      : (isDark
                          ? AppColors.brand.withValues(alpha: 0.15)
                          : AppColors.brandSurface),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isZero ? scheme.error : AppColors.brand,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.item.name,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                    Text(
                      _splitTypeLabel(state.item.splitType),
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isZero)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(
                    'Required',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onErrorContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Amount field
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
              labelText: 'Amount',
              hintText: 'Enter actual amount',
              prefixIcon: Icon(
                Icons.payments_outlined,
                color: isZero ? scheme.error : scheme.primary,
                size: 20,
              ),
              suffixText: '₫',
              suffixStyle: TextStyle(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              filled: true,
              fillColor: isZero
                  ? scheme.errorContainer.withValues(alpha: 0.3)
                  : (isDark ? scheme.surfaceContainerHighest : scheme.surfaceContainerLowest),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide(color: scheme.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide(
                  color: isZero
                      ? scheme.error.withValues(alpha: 0.4)
                      : scheme.outlineVariant,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadii.sm),
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
            ),
          ),

          // Assigned members
          if (state.item.assignedToNames.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: state.item.assignedToNames.map<Widget>((name) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.brand.withValues(alpha: 0.1)
                        : AppColors.brandSurface,
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Text(
                    name,
                    style: textTheme.labelSmall?.copyWith(
                      color: isDark ? AppColors.brandLight : AppColors.brandDark,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],

          // Per-person share preview
          if (amount > 0 && state.item.assignedTo.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.green.shade50,
                borderRadius: BorderRadius.circular(AppSpacing.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 14,
                    color: isDark ? Colors.green.shade300 : Colors.green.shade700,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'Per person: ${CurrencyFormatter.formatVND(amount / state.item.assignedTo.length)}',
                    style: textTheme.labelSmall?.copyWith(
                      color: isDark ? Colors.green.shade300 : Colors.green.shade700,
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
