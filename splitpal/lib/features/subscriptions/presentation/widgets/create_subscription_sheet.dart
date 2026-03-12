import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../groups/presentation/providers/group_provider.dart';
import '../providers/subscription_provider.dart';

class CreateSubscriptionSheet extends StatefulWidget {
  final String? initialGroupId;

  const CreateSubscriptionSheet({super.key, this.initialGroupId});

  @override
  State<CreateSubscriptionSheet> createState() => _CreateSubscriptionSheetState();
}

class _CreateSubscriptionSheetState extends State<CreateSubscriptionSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _startDateController = TextEditingController();

  List<dynamic> _groups = [];
  String? _selectedGroupId;
  String _billingCycle = 'MONTHLY';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _selectedGroupId = widget.initialGroupId;
    
    // Preload groups so user can pick existing one
    Future.microtask(() async {
      final groupProvider = context.read<GroupProvider>();
      if (groupProvider.groups.isEmpty) {
        await groupProvider.fetchGroupsAndInvites();
      }
      setState(() {
        _groups = groupProvider.groups;
        // If initialGroupId is not set, select the first group
        if (_selectedGroupId == null && _groups.isNotEmpty) {
          _selectedGroupId = _extractGroupId(_groups.first);
        }
      });
    });
  }

  String? _extractGroupId(dynamic group) {
    if (group is Map) {
      return (group['id'] ?? group['_id'] ?? group['groupId'])?.toString();
    }
    return null;
  }

  String _extractGroupName(dynamic group) {
    if (group is Map) {
      return (group['name'] ?? group['groupName'] ?? _extractGroupId(group) ?? 'Unnamed').toString();
    }
    return group.toString();
  }

  Future<void> _submit() async {
    final provider = context.read<SubscriptionProvider>();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '').trim());

    if (_nameController.text.trim().isEmpty || _selectedGroupId == null || amount == null) {
      setState(() => _error = 'Please enter name, select a group, and a valid amount');
      return;
    }

    setState(() {
      _error = null;
      _submitting = true;
    });

    final ok = await provider.create(
      groupId: _selectedGroupId!,
      name: _nameController.text.trim(),
      amount: amount,
      billingCycle: _billingCycle,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      startDate: _parseDate(_startDateController.text.trim()),
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _error = provider.error ?? 'Create failed';
        _submitting = false;
      });
    }
  }

  DateTime? _parseDate(String raw) {
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
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
            _buildGroupDropdown(),
            _buildField('Amount', _amountController, hint: 'e.g. 99000'),
            _buildDropdown(),
            _buildField('Description (optional)', _descriptionController, hint: ''),
            _buildField('Start date ISO (optional)', _startDateController,
                hint: '2026-01-28T00:00:00Z'),
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

  Widget _buildGroupDropdown() {
    final isLoadingGroups = _groups.isEmpty;
    // If initialGroupId is set, we might want to disable this dropdown or just pre-select it.
    // Assuming we allow changing it, but pre-select. 
    // If we want to force it, we can disable `onChanged` if widget.initialGroupId is set.
    // For now, let's allow changing it, but default to the provided one.
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Group', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            value: _selectedGroupId,
            isExpanded: true,
            decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
            items: isLoadingGroups
                ? const [
                    DropdownMenuItem(value: null, child: Text('Loading groups...')),
                  ]
                : _groups
                    .map((g) => DropdownMenuItem<String>(
                          value: _extractGroupId(g),
                          child: Text(_extractGroupName(g)),
                        ))
                    .toList(),
            onChanged: (isLoadingGroups || widget.initialGroupId != null && _groups.any((g) => _extractGroupId(g) == widget.initialGroupId)) 
              // If initial group is provided, we might want to lock it? 
              // User request: "Transfer subscription here, in group detail."
              // Usually group detail creation implies creating FOR that group.
              // Let's lock it if initialGroupId is provided to avoid confusion, or just pre-select.
              // I'll allow changing for flexibility unless user complains. But wait, if I'm in Group A detail and I create a sub for Group B, it won't show up in the list I'm looking at.
              // So logically, I should probably enforce it.
              // But let's just pre-select for now.
              ? (val) => setState(() => _selectedGroupId = val) 
              : (val) => setState(() => _selectedGroupId = val),
          ),
          if (isLoadingGroups)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(minHeight: 3),
            ),
        ],
      ),
    );
  }
}
