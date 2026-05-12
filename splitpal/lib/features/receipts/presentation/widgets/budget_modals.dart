import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/models/receipt.dart';
import 'package:splitpal/features/receipts/receipt_provider.dart';
import 'package:splitpal/features/receipts/presentation/widgets/icon_helpers.dart';

Color colorFromHex(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

void showTagEditor(BuildContext context, {ReceiptTag? tag}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TagEditorModal(tag: tag),
  ).then((_) {
    // Refresh triggered via Provider listeners automatically usually
  });
}

void showTagDeleteConfirm(BuildContext context, ReceiptTag tag) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Category'),
      content: const Text('Do you want to permanently delete or just archive this category?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            await context.read<ReceiptProvider>().updateTag(tag.id, isArchived: true);
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Category archived')));
            }
          },
          child: const Text('Archive', style: TextStyle(color: Colors.orange)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final success = await context.read<ReceiptProvider>().deleteTag(tag.id);
            if (context.mounted && !success) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.read<ReceiptProvider>().error ?? 'Cannot delete. Try archiving instead.')),
              );
            }
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

class _TagEditorModal extends StatefulWidget {
  final ReceiptTag? tag;

  const _TagEditorModal({this.tag});

  @override
  State<_TagEditorModal> createState() => _TagEditorModalState();
}

class _TagEditorModalState extends State<_TagEditorModal> {
  late TextEditingController _nameCtrl;
  late TextEditingController _budgetCtrl;
  late TextEditingController _iconCtrl;
  String _selectedColor = '#4F46E5';
  late List<String> _colors;

  static const List<String> _presetColors = [
    '#4F46E5', '#0EA5E9', '#22C55E', '#F59E0B', '#EF4444', '#EC4899', '#10B981', '#6366F1'
  ];
  
  static const List<String> _emojis = [
    '🍔', '🚗', '🍿', '🛍️', '💡', '💊', '📚', '✈️', '🎁'
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.tag?.name ?? '');
    _budgetCtrl = TextEditingController(text: widget.tag?.monthlyBudget != null ? CurrencyFormatter.formatInput(widget.tag!.monthlyBudget!.toInt()) : '');
    _iconCtrl = TextEditingController(text: materialIconToEmoji(widget.tag?.icon) ?? widget.tag?.icon ?? '🏷️');
    _selectedColor = widget.tag?.color ?? _presetColors.first;

    // Include the existing tag's color in the picker if not already preset
    if (widget.tag != null && !_presetColors.contains(widget.tag!.color)) {
      _colors = [widget.tag!.color, ..._presetColors];
    } else {
      _colors = _presetColors;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetCtrl.dispose();
    _iconCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final provider = context.read<ReceiptProvider>();
    final budget = CurrencyFormatter.parseFormatted(_budgetCtrl.text);
    
    if (budget == null || budget <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Monthly budget is required and must be greater than 0')),
      );
      return;
    }

    final icon = _iconCtrl.text.trim();

    bool success;
    if (widget.tag == null) {
      final tag = await provider.createTag(name, _selectedColor, monthlyBudget: budget, icon: icon);
      success = tag != null;
    } else {
      success = await provider.updateTag(widget.tag!.id, name: name, color: _selectedColor, monthlyBudget: budget, icon: icon);
    }

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error ?? 'Failed to save category')),
      );
      return;
    }

    // Reload budget summary so the page reflects changes
    final now = DateTime.now();
    final monthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    provider.loadBudgetSummary(monthStr);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.tag != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: bottomInset + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isEdit ? 'Edit Category' : 'New Category',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 70,
                  child: TextField(
                    controller: _iconCtrl,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28),
                    decoration: InputDecoration(
                      labelText: 'Emoji',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Category Name',
                      hintText: 'e.g. Food & Dining',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _budgetCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Monthly Budget *',
                hintText: 'e.g. 5.000.000',
                prefixText: '₫ ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Preset Emojis', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _emojis.map((e) {
                final isSelected = _iconCtrl.text.trim() == e;
                return GestureDetector(
                  onTap: () => setState(() => _iconCtrl.text = e),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary.withAlpha(50) : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
                    ),
                    child: Center(
                      child: Text(e, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Color Theme', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _colors.map((c) {
                final color = colorFromHex(c);
                final isSelected = _selectedColor == c;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withAlpha(isSelected ? 255 : 100),
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: theme.colorScheme.onSurface, width: 2) : null,
                    ),
                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

