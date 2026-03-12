import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'create_invoice_page.dart';

class InvoiceCaptureModePage extends StatelessWidget {
  final String groupId;

  const InvoiceCaptureModePage({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Header
              const SizedBox(height: 40),
              Icon(
                Icons.receipt_long,
                size: 64,
                color: AppColors.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'How would you like to add an invoice?',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.midnightBlue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose a method to get started',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.silver,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Option 1: OCR (Camera)
              _buildCaptureOption(
                context: context,
                icon: Icons.camera_alt,
                title: 'Capture Invoice',
                subtitle: 'Take a photo or upload\nLet AI extract data automatically',
                color: AppColors.primary,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateInvoicePage(groupId: groupId),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Divider
              Row(
                children: [
                  Expanded(child: Divider(color: AppColors.silver.withOpacity(0.3))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: AppColors.silver,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.silver.withOpacity(0.3))),
                ],
              ),
              const SizedBox(height: 16),

              // Option 2: Manual Entry
              _buildCaptureOption(
                context: context,
                icon: Icons.edit_note,
                title: 'Manual Entry',
                subtitle: 'Fill in the details\nEnter invoice info manually',
                color: Colors.blue[400]!,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CreateInvoicePage(groupId: groupId),
                    ),
                  );
                },
              ),

              const Spacer(),

              // Tip
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Tip: Camera capture is faster and more accurate for invoices with clear text.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[700],
                        ),
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

  Widget _buildCaptureOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.midnightBlue,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.silver,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(),
                Icon(
                  Icons.arrow_forward,
                  color: color,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
