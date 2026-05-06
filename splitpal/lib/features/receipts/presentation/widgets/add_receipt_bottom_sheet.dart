import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/constants/app_colors.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/models/receipt.dart';
import 'package:splitpal/features/receipts/receipt_provider.dart';
import 'package:intl/intl.dart';
import '../pages/budget_page.dart';

class AddReceiptBottomSheet extends StatefulWidget {
  final DateTime defaultDate;
  final VoidCallback? onCreated;

  const AddReceiptBottomSheet({
    super.key,
    required this.defaultDate,
    this.onCreated,
  });

  @override
  State<AddReceiptBottomSheet> createState() => _AddReceiptBottomSheetState();
}

class _AddReceiptBottomSheetState extends State<AddReceiptBottomSheet> {
  final ImagePicker _picker = ImagePicker();
  File? _file;
  Uint8List? _fileBytes;
  String? _fileName;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController(text: '0');
  final Set<String> _selectedTagIds = {};
  bool _uploading = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.defaultDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReceiptProvider>().loadTags();
    });
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      try {
        final bytes = await picked.readAsBytes();
        final file = File(picked.path);
        setState(() {
          _file = file;
          _fileBytes = bytes;
          _fileName = picked.name;
          _scanning = true;
        });
        if (mounted) {
          final amount = await context.read<ReceiptProvider>().scanReceiptWithAI(bytes, picked.name);
          if (mounted) {
            setState(() {
               _scanning = false;
               if (amount != null && amount > 0) {
                 final formatter = NumberFormat('#,##0', 'en_US');
                 _amountCtrl.text = formatter.format(amount.round());
               }
            });
          }
        }
      } catch (e) {
        debugPrint('Image pick error: $e');
        setState(() => _scanning = false);
      }
    }
  }

  Future<void> _save() async {
    final provider = context.read<ReceiptProvider>();
    if (_file == null || _fileBytes == null || _fileName == null || _selectedTagIds.isEmpty) return;
    setState(() => _uploading = true);
    final result = await provider.createReceiptFromFile(
      bytes: _fileBytes!,
      fileName: _fileName!,
      receiptDate: _selectedDate,
      totalAmount: double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0.0,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      tagIds: _selectedTagIds.toList(),
    );
    setState(() => _uploading = false);
    if (result != null) {
      widget.onCreated?.call();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _openTagManager() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BudgetPage()));
    await context.read<ReceiptProvider>().loadTags();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    final tags = provider.tags;
    final canSave = _file != null && _selectedTagIds.isNotEmpty && !_uploading;

    // ── Pre-capture state: camera/gallery picker ──
    if (_file == null) {
      return _buildPickerSheet(context);
    }

    // ── Post-capture state: image preview + tagging ──
    return _buildPreviewSheet(context, provider, tags, canSave);
  }

  // ─────────────────────────────────────────────────────────────
  // Initial picker (no image yet)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPickerSheet(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Container(
            width: 40, height: 5,
            margin: const EdgeInsets.only(bottom: AppSpacing.xl),
            decoration: BoxDecoration(
              color: AppColors.silver,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          Icon(Icons.camera_alt, size: 64, color: scheme.primary),
          const SizedBox(height: AppSpacing.lg),
          Text('Add Receipt',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Snap a photo of your receipt to upload it.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.concrete),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 56,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
              ),
              onPressed: () => _pick(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Take Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity, height: 56,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
              ),
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Choose from Gallery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Post-capture: full-screen image with bottom overlay
  // ─────────────────────────────────────────────────────────────
  Widget _buildPreviewSheet(
    BuildContext context,
    ReceiptProvider provider,
    List<ReceiptTag> tags,
    bool canSave,
  ) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppColors.charcoal,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
      ),
      child: Stack(
        children: [
          // ── Full-bleed image ──
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.lg)),
              child: _fileBytes != null
                  ? Image.memory(_fileBytes!, fit: BoxFit.cover)
                  : Image.file(_file!, fit: BoxFit.cover),
            ),
          ),

          // ── Bottom gradient scrim ──
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 380,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppColors.charcoal.withOpacity(0.6),
                    AppColors.charcoal.withOpacity(0.92),
                    AppColors.charcoal,
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
              ),
            ),
          ),

          // ── Bottom controls ──
          Positioned(
            left: AppSpacing.lg,
            right: AppSpacing.lg,
            bottom: bottomInset + AppSpacing.xl,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error banner
                if (provider.error != null)
                  _buildErrorBanner(provider.error!),

                // Tags
                _buildTagSection(tags),
                const SizedBox(height: AppSpacing.lg),

                // Amount + Note + Send
                _buildInputRow(canSave),
              ],
            ),
          ),

          // ── Close button ──
          Positioned(
            top: AppSpacing.xl, left: AppSpacing.lg,
            child: _buildCloseButton(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Error banner
  // ─────────────────────────────────────────────────────────────
  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFB91C1C).withOpacity(0.85),
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white, size: 16),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(error,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Tag section: wrapping chips, no horizontal truncation
  // ─────────────────────────────────────────────────────────────
  Widget _buildTagSection(List<ReceiptTag> tags) {
    if (tags.isEmpty) {
      return TextButton.icon(
        style: TextButton.styleFrom(
          backgroundColor: Colors.black45,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
        ),
        onPressed: _openTagManager,
        icon: const Icon(Icons.add, color: Colors.white, size: 18),
        label: const Text('Create a category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      );
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        ...tags.map((t) {
          final isSelected = _selectedTagIds.contains(t.id);
          return ChoiceChip(
            showCheckmark: false,
            label: Text(
              t.name.toUpperCase(),
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w700,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
            selected: isSelected,
            selectedColor: AppColors.brand,
            backgroundColor: Colors.black45,
            side: isSelected
                ? const BorderSide(color: AppColors.brandLight, width: 1.5)
                : BorderSide.none,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            onSelected: (_) {
              setState(() {
                if (_selectedTagIds.contains(t.id)) {
                  _selectedTagIds.remove(t.id);
                } else {
                  _selectedTagIds.add(t.id);
                }
              });
            },
          );
        }),
        ActionChip(
          label: const Icon(Icons.tune, size: 16, color: Colors.white70),
          backgroundColor: Colors.black38,
          side: BorderSide.none,
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(AppSpacing.xs),
          onPressed: _openTagManager,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Input row: Amount | Note | Send
  // ─────────────────────────────────────────────────────────────
  Widget _buildInputRow(bool canSave) {
    // Shared input decoration that kills ALL theme borders
    const noBorders = InputBorder.none;

    return Row(
      children: [
        // Amount field
        Expanded(
          flex: 3,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              cursorColor: Colors.white70,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                hintText: '0',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                border: noBorders,
                enabledBorder: noBorders,
                focusedBorder: noBorders,
                errorBorder: noBorders,
                disabledBorder: noBorders,
                prefixIcon: _scanning
                    ? Container(
                        width: 16, height: 16,
                        padding: const EdgeInsets.all(12),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      )
                    : Icon(Icons.payments_outlined, color: Colors.white.withOpacity(0.5), size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 36),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.sm),

        // Note field
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: TextField(
              controller: _noteCtrl,
              cursorColor: Colors.white70,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.transparent,
                hintText: 'Note (optional)',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                border: noBorders,
                enabledBorder: noBorders,
                focusedBorder: noBorders,
                errorBorder: noBorders,
                disabledBorder: noBorders,
                prefixIcon: Icon(Icons.edit_note, color: Colors.white.withOpacity(0.5), size: 20),
                prefixIconConstraints: const BoxConstraints(minWidth: 32),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        const SizedBox(width: AppSpacing.md),

        // Send button
        GestureDetector(
          onTap: canSave ? _save : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: canSave ? AppColors.brand : Colors.black38,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: _uploading
                ? const Center(
                    child: SizedBox(
                      height: 20, width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  )
                : Icon(
                    Icons.check,
                    color: canSave ? Colors.white : Colors.white.withOpacity(0.3),
                    size: 22,
                  ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Close button
  // ─────────────────────────────────────────────────────────────
  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: AppColors.charcoal.withOpacity(0.6),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 20),
      ),
    );
  }
}
