import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/features/subscriptions/subscription_provider.dart';

class CreateSubscriptionSheet extends StatefulWidget {
  const CreateSubscriptionSheet({super.key});

  @override
  State<CreateSubscriptionSheet> createState() => _CreateSubscriptionSheetState();
}

class _CreateSubscriptionSheetState extends State<CreateSubscriptionSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _billingCycle = 'MONTHLY';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final provider = context.read<SubscriptionProvider>();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim());

    if (_nameController.text.trim().isEmpty || amount == null || amount <= 0) {
      setState(() => _error = 'Please enter a name and a valid amount');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final ok = await provider.create(
      name: _nameController.text.trim(),
      amount: amount,
      billingCycle: _billingCycle,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = provider.actionError ?? 'Create failed';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(
        bottom: viewInsets,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Create subscription',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
            const SizedBox(height: 8),
            _buildField('Service name', _nameController, hint: 'Netflix, Spotify...'),
            _buildField('Amount (per member/cycle)', _amountController, hint: 'e.g. 99000'),
            _buildDropdown(),
            _buildField('Description (optional)', _descriptionController, hint: ''),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create'),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {String? hint}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              hintText: hint,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Billing cycle', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _billingCycle,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: 'DAILY', child: Text('Daily')),
              DropdownMenuItem(value: 'WEEKLY', child: Text('Weekly')),
              DropdownMenuItem(value: 'MONTHLY', child: Text('Monthly')),
              DropdownMenuItem(value: 'YEARLY', child: Text('Yearly')),
            ],
            onChanged: (val) => setState(() => _billingCycle = val ?? 'MONTHLY'),
          ),
        ],
      ),
    );
  }
}
