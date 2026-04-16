import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import 'package:splitpal/features/ai/ai_provider.dart';

class InvoiceOcrPicker {
  static Future<void> showOcrBottomSheet(
    BuildContext context, {
    required Function(InvoiceOcrData) onDataExtracted,
  }) {
    final hostContext = context;

    return showModalBottomSheet(
      context: context,
      builder: (context) => _OcrPickerSheet(
        hostContext: hostContext,
        onDataExtracted: onDataExtracted,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
    );
  }
}

class _OcrPickerSheet extends StatelessWidget {
  final BuildContext hostContext;
  final Function(InvoiceOcrData) onDataExtracted;

  const _OcrPickerSheet({
    required this.hostContext,
    required this.onDataExtracted,
  });

  Future<void> _captureImage(BuildContext sheetContext) async {
    try {
      final XFile? photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (photo != null && sheetContext.mounted && hostContext.mounted) {
        Navigator.pop(sheetContext); // Close bottom sheet
        await _processImage(hostContext, File(photo.path));
      }
    } catch (e) {
      if (hostContext.mounted) {
        ScaffoldMessenger.of(hostContext).showSnackBar(
          SnackBar(content: Text('Camera error: $e')),
        );
      }
    }
  }

  Future<void> _pickImage(BuildContext sheetContext) async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image != null && sheetContext.mounted && hostContext.mounted) {
        Navigator.pop(sheetContext); // Close bottom sheet
        await _processImage(hostContext, File(image.path));
      }
    } catch (e) {
      if (hostContext.mounted) {
        ScaffoldMessenger.of(hostContext).showSnackBar(
          SnackBar(content: Text('Gallery error: $e')),
        );
      }
    }
  }

  Future<void> _processImage(BuildContext context, File imageFile) async {
    if (!context.mounted) return;

    final aiProvider = context.read<AiProvider>();
    final result = await aiProvider.processInvoiceImage(imageFile);

    if (!context.mounted) return;

    if (result?.extractionError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('OCR Error: ${result?.extractionError}'),
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }

    if (result == null) {
      final errorMessage = aiProvider.errorMessage ?? 'Failed to process invoice image';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }

    // Show preview dialog before confirming
    _showOcrPreview(context, result, imageFile);
  }

  void _showOcrPreview(
    BuildContext context,
    InvoiceOcrData data,
    File imageFile,
  ) {
    showDialog(
      context: context,
      builder: (context) => _OcrPreviewDialog(
        data: data,
        imageFile: imageFile,
        onConfirm: () {
          Navigator.pop(context); // Close preview
          onDataExtracted(data);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Extract Invoice Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.midnightBlue,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _captureImage(context),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(context),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.silver),
            ),
          ),
        ],
      ),
    );
  }
}

class _OcrPreviewDialog extends StatelessWidget {
  final InvoiceOcrData data;
  final File imageFile;
  final VoidCallback onConfirm;

  const _OcrPreviewDialog({
    required this.data,
    required this.imageFile,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final confidenceColor = _getConfidenceColor(data.confidence);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: confidenceColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Extracted Data',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.midnightBlue,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: confidenceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      data.confidence,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      imageFile,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildPreviewRow('Title', data.title),
                  _buildPreviewRow(
                    'Date',
                    '${data.invoiceDate.year}-${data.invoiceDate.month.toString().padLeft(2, '0')}-${data.invoiceDate.day.toString().padLeft(2, '0')}',
                  ),
                  _buildPreviewRow('Currency', data.currency),
                  _buildPreviewRow('Total', data.amountTotal.toStringAsFixed(2)),
                  if (data.items.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Items:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.midnightBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...data.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: AppColors.midnightBlue,
                              ),
                            ),
                            Text(
                              'Qty: ${item.quantity} x ${item.unitPrice} = ${item.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ],
                  if (data.note != null && data.note!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildPreviewRow('Note', data.note!),
                  ],
                  if (data.confidence == 'LOW') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        border: Border.all(color: Colors.orange[200]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Low confidence. Please review and edit before saving.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Action buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: const BorderSide(color: AppColors.silver),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.midnightBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onConfirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Use This Data',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildPreviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.silver,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.midnightBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(String confidence) {
    switch (confidence) {
      case 'HIGH':
        return Colors.green;
      case 'MEDIUM':
        return Colors.orange;
      case 'LOW':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
