import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/invoices/bill_template_provider.dart';
import 'package:splitpal/features/groups/group_provider.dart';
import 'package:splitpal/models/bill_template.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/widgets/app_section_header.dart';
import 'package:splitpal/core/icons/app_icons.dart';

class CreateBillTemplatePage extends StatefulWidget {
  final String groupId;

  const CreateBillTemplatePage({Key? key, required this.groupId}) : super(key: key);

  @override
  State<CreateBillTemplatePage> createState() => _CreateBillTemplatePageState();
}

class _CreateBillTemplatePageState extends State<CreateBillTemplatePage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // ── Step 1 State ─────────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _billingCycle = 'MONTHLY';
  int _billingDay = 5;
  String? _payerId;

  // ── Step 2 State ─────────────────────────────────────────────────────────────
  final List<_ItemDraft> _items = [];

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _getMemberName(dynamic member) {
    if (member is! Map<String, dynamic>) return 'Unknown';
    final user = member['user'];
    if (user != null && user is Map<String, dynamic>) {
      return (user['displayName'] ?? user['email'] ?? 'Unknown').toString();
    }
    return (member['displayName'] ?? member['name'] ?? member['email'] ?? 'Unknown').toString();
  }

  List<String> get _memberIds {
    final gp = context.read<GroupProvider>();
    return gp.currentGroupMembers
        .map((m) => (m as Map<String, dynamic>)['userId']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();
  }

  Map<String, String> get _memberNames {
    final gp = context.read<GroupProvider>();
    return {
      for (final m in gp.currentGroupMembers)
        (m as Map<String, dynamic>)['userId']?.toString() ?? '':
            _getMemberName(m)
    };
  }

  double get _totalAmount => _items.fold(0, (s, i) => s + i.amount);

  bool get _step1Valid =>
      _nameCtrl.text.trim().isNotEmpty &&
      (_billingCycle != 'WEEKLY' || (_billingDay >= 1 && _billingDay <= 7)) &&
      (_billingCycle != 'MONTHLY' || (_billingDay >= 1 && _billingDay <= 28));

  bool get _step2Valid => _items.isNotEmpty;

  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(
      step,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _submit() async {
    final members = _memberIds;
    final request = BillTemplateRequest(
      name: _nameCtrl.text.trim(),
      description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      billingCycle: _billingCycle,
      billingDay: _billingCycle == 'DAILY' ? null : _billingDay,
      items: _items.map((d) => BillTemplateItem(
        name: d.nameCtrl.text,
        amount: d.amount,
        splitType: d.splitType,
        assignedTo: d.assignedTo.isEmpty ? members : d.assignedTo,
        splits: d.splitControllers.entries
            .map((e) => BillTemplateItemSplit(userId: e.key, value: double.tryParse(e.value.text) ?? 0))
            .where((s) => s.value > 0).toList(),
      )).toList(),
      payerId: _payerId,
    );

    final provider = context.read<BillTemplateProvider>();
    final ok = await provider.createTemplate(widget.groupId, request);

    if (!mounted) return;

    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Created template "${request.name}"'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'An error occurred'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameCtrl.dispose();
    _descCtrl.dispose();
    for (var i in _items) {
      i.nameCtrl.dispose();
      i.amountCtrl.dispose();
    }
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Create Bill Template'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (_currentStep + 1) / 3,
            backgroundColor: scheme.primaryContainer,
            valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
          ),
        ),
      ),
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildStep1(),
          _buildStep2(),
          _buildStep3(),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    final members = context.watch<GroupProvider>().currentGroupMembers;
    final eligiblePayers = members.where((m) {
      if (m is! Map<String, dynamic>) return false;
      final role = m['role']?.toString().toUpperCase();
      return role == 'OWNER' || role == 'ADMIN';
    }).toList();

    return SingleChildScrollView(
      padding: AppSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(
            title: 'Step 1 of 3: Basic Details',
          ),
          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Template Name *'),
                TextFormField(
                  controller: _nameCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDeco('e.g., Rent, Electricity...'),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSpacing.lg),
                _fieldLabel('Description (optional)'),
                TextFormField(
                  controller: _descCtrl,
                  decoration: _inputDeco('Add a note...'),
                  maxLines: 2,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Payer *'),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String>(
                  value: _payerId ?? (eligiblePayers.isNotEmpty
                      ? (eligiblePayers.first as Map<String, dynamic>)['userId']?.toString()
                      : null),
                  decoration: _inputDeco(null),
                  items: eligiblePayers.map((m) {
                    final map = m as Map<String, dynamic>;
                    final uid = map['userId']?.toString() ?? '';
                    final name = _getMemberName(m);
                    return DropdownMenuItem<String>(
                      value: uid,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _payerId = v),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _fieldLabel('Billing Cycle *'),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _cycleChip('DAILY', 'Daily'),
                    _cycleChip('WEEKLY', 'Weekly'),
                    _cycleChip('MONTHLY', 'Monthly'),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_billingCycle == 'WEEKLY') ...[
                  _fieldLabel('Day of the week'),
                  const SizedBox(height: AppSpacing.xs),
                  _weekdayPicker(),
                ],
                if (_billingCycle == 'MONTHLY') ...[
                  _fieldLabel('Day of the month: $_billingDay'),
                  Slider(
                    value: _billingDay.toDouble(),
                    min: 1,
                    max: 28,
                    divisions: 27,
                    activeColor: Theme.of(context).colorScheme.primary,
                    label: 'Day $_billingDay',
                    onChanged: (v) => setState(() => _billingDay = v.round()),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _step1Valid ? () => _goToStep(1) : null,
              child: const Text('Next →'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: AppSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSectionHeader(
                  title: 'Step 2 of 3: Cost Items',
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_items.isEmpty)
                  AppCard(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'No items yet. Tap + to add.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ..._items.asMap().entries.map((e) => _itemCard(e.key, e.value)),
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(AppIcons.add),
                  label: const Text('Add Item'),
                ),
                if (_items.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatVND(_totalAmount),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                OutlinedButton(
                  onPressed: () => _goToStep(0),
                  child: const Text('← Back'),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: FilledButton(
                    onPressed: _step2Valid ? () => _goToStep(2) : null,
                    child: const Text('Preview →'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _itemCard(int index, _ItemDraft item) {
    final gp = context.read<GroupProvider>();
    final members = gp.currentGroupMembers;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.nameCtrl,
                    decoration: _inputDeco('Item Name (e.g., Rent)'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.delete, color: scheme.error),
                  onPressed: () => setState(() => _items.removeAt(index)),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: item.amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDeco('Amount (0 = Enter later)'),
                    onChanged: (v) => setState(() => item.amount = double.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  decoration: BoxDecoration(
                    border: Border.all(color: scheme.outlineVariant),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: DropdownButton<String>(
                    value: item.splitType,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'EQUAL', child: Text('Equal')),
                      DropdownMenuItem(value: 'PERCENTAGE', child: Text('Percentage')),
                      DropdownMenuItem(value: 'CUSTOM', child: Text('Custom')),
                    ],
                    onChanged: (v) => setState(() => item.splitType = v!),
                  ),
                ),
              ],
            ),
            if (item.amount == 0)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  '⚡ Amount = 0: Payer will enter upon confirmation',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.tertiary,
                  ),
                ),
              ),

            const SizedBox(height: AppSpacing.md),
            _fieldLabel('Assigned To (Leave empty to assign all)'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: members.map((m) {
                final uid = (m as Map<String, dynamic>)['userId']?.toString() ?? '';
                if (uid.isEmpty) return const SizedBox.shrink();
                final isSelected = item.assignedTo.contains(uid);
                return FilterChip(
                  selected: isSelected,
                  label: Text(
                    _getMemberName(m),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? scheme.onPrimary : scheme.onSurface,
                    ),
                  ),
                  selectedColor: scheme.primary,
                  checkmarkColor: scheme.onPrimary,
                  backgroundColor: scheme.surface,
                  side: BorderSide(
                    color: isSelected ? scheme.primary : scheme.outlineVariant,
                  ),
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        item.assignedTo.add(uid);
                        item.splitControllers.putIfAbsent(uid, () => TextEditingController());
                      } else {
                        item.assignedTo.remove(uid);
                      }
                    });
                  },
                );
              }).toList(),
            ),

            if (item.splitType != 'EQUAL' && item.assignedTo.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              _fieldLabel(item.splitType == 'PERCENTAGE' ? 'Split Percentages' : 'Custom Amounts'),
              ...item.assignedTo.map((uid) {
                final m = members.firstWhere(
                  (member) => (member as Map<String, dynamic>)['userId']?.toString() == uid,
                  orElse: () => <String, dynamic>{},
                );
                item.splitControllers.putIfAbsent(uid, () => TextEditingController());
                final controller = item.splitControllers[uid]!;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          _getMemberName(m),
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          controller: controller,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: _inputDeco('0').copyWith(
                            suffix: item.splitType == 'PERCENTAGE'
                                ? Text('%', style: TextStyle(color: scheme.onSurface))
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ],
        ),
      ),
    );
  }

  void _addItem() {
    setState(() {
      _items.add(_ItemDraft());
    });
  }

  Widget _buildStep3() {
    final members = context.watch<GroupProvider>().currentGroupMembers;
    final memberCount = members.length;

    final now = DateTime.now();
    DateTime nextDate;
    if (_billingCycle == 'DAILY') {
      nextDate = now.add(const Duration(days: 1));
    } else if (_billingCycle == 'WEEKLY') {
      final dow = now.weekday;
      final diff = ((_billingDay - dow + 7) % 7).clamp(1, 7);
      nextDate = now.add(Duration(days: diff));
    } else {
      nextDate = DateTime(
        now.month == 12 ? now.year + 1 : now.year,
        now.month == 12 ? 1 : now.month + 1,
        _billingDay.clamp(1, 28),
      );
    }

    return Consumer<BillTemplateProvider>(
      builder: (context, provider, _) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.pagePadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppSectionHeader(
                      title: 'Step 3 of 3: Preview',
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(AppIcons.refresh, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Text(
                                  _nameCtrl.text.trim(),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _previewRow('Cycle', _cycleDescription()),
                          _previewRow(
                            'First bill date',
                            '${nextDate.day}/${nextDate.month}/${nextDate.year}',
                            highlight: true,
                          ),
                          _previewRow('Payer', _payerName(members)),
                          const Divider(height: AppSpacing.xl),
                          ..._items.map((item) => Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                            child: Row(
                              children: [
                                Expanded(child: Text(item.nameCtrl.text.isEmpty ? '(unnamed)' : item.nameCtrl.text)),
                                Text(
                                  item.amount == 0
                                      ? 'Enter later'
                                      : CurrencyFormatter.formatVND(item.amount),
                                  style: TextStyle(
                                    color: item.amount == 0 ? Theme.of(context).colorScheme.tertiary : null,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )),
                          const Divider(height: AppSpacing.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Total', style: Theme.of(context).textTheme.titleMedium),
                              Text(
                                CurrencyFormatter.formatVND(_totalAmount),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    if (_totalAmount > 0 && memberCount > 0) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Estimated amount per person (Equal)',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            ...members.map((m) => Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                              child: Row(
                                children: [
                                  Icon(AppIcons.person, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      _getMemberName(m),
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    )
                                  ),
                                  Text(
                                    CurrencyFormatter.formatVND(_totalAmount / memberCount),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: () => _goToStep(1),
                      child: const Text('← Back'),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: provider.isLoading ? null : _submit,
                        icon: provider.isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(AppIcons.checkCircle),
                        label: const Text('Create Template'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _cycleDescription() {
    switch (_billingCycle) {
      case 'DAILY': return 'Daily';
      case 'WEEKLY':
        const days = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return 'Weekly · ${days[_billingDay]}';
      case 'MONTHLY': return 'Monthly · Day $_billingDay';
      default: return _billingCycle;
    }
  }

  String _payerName(List members) {
    if (members.isEmpty) return 'Unknown';
    final targetId = _payerId;
    if (targetId == null) {
      final first = members.first as Map<String, dynamic>;
      return _getMemberName(first);
    }
    final m = members.cast<Map<String, dynamic>>().firstWhere(
      (m) => m['userId']?.toString() == targetId,
      orElse: () => <String, dynamic>{},
    );
    return m.isNotEmpty ? _getMemberName(m) : 'Unknown';
  }

  Widget _cycleChip(String value, String label) {
    final selected = _billingCycle == value;
    final scheme = Theme.of(context).colorScheme;
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() {
        _billingCycle = value;
        _billingDay = value == 'WEEKLY' ? 1 : 5;
      }),
      selectedColor: scheme.primaryContainer,
      checkmarkColor: scheme.onPrimaryContainer,
      labelStyle: TextStyle(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _weekdayPicker() {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: List.generate(7, (i) {
        final day = i + 1;
        final sel = _billingDay == day;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _billingDay = day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: sel ? scheme.primaryContainer : scheme.surface,
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: sel ? scheme.primary : scheme.outlineVariant),
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: sel ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  InputDecoration _inputDeco(String? hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.sm),
      borderSide: BorderSide.none,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md),
  );

  Widget _previewRow(String label, String value, {bool highlight = false}) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: highlight ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    ),
  );
}

class _ItemDraft {
  final nameCtrl = TextEditingController();
  final amountCtrl = TextEditingController(text: '0');
  double amount = 0;
  String splitType = 'EQUAL';
  List<String> assignedTo = [];
  Map<String, TextEditingController> splitControllers = {};
}
