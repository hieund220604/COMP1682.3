import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/savings/savings_provider.dart';

/// Bottom sheet for creating a new deposit into a savings goal.
/// Shows amount input, term selector (chips), and live interest preview.
class CreateDepositSheet extends StatefulWidget {
  final String goalId;

  const CreateDepositSheet({super.key, required this.goalId});

  @override
  State<CreateDepositSheet> createState() => _CreateDepositSheetState();
}

class _CreateDepositSheetState extends State<CreateDepositSheet> {
  final _amountCtrl = TextEditingController();
  int _selectedTerm = 30; // default 1 month
  bool _isSubmitting = false;

  // Preview data
  Map<String, dynamic>? _preview;
  bool _loadingPreview = false;

  static const _terms = [
    {'days': 0, 'label': 'Flexible'},
    {'days': 30, 'label': '1 Month'},
    {'days': 90, 'label': '3 Months'},
    {'days': 180, 'label': '6 Months'},
    {'days': 365, 'label': '12 Months'},
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPreview() async {
    final amount = CurrencyFormatter.parseFormatted(_amountCtrl.text);
    if (amount == null || amount <= 0) {
      setState(() => _preview = null);
      return;
    }

    setState(() => _loadingPreview = true);
    final provider = context.read<SavingsProvider>();
    final preview = await provider.getInterestPreview(amount: amount, term: _selectedTerm);
    if (mounted) {
      setState(() {
        _preview = preview;
        _loadingPreview = false;
      });
    }
  }

  Future<void> _submit() async {
    final amount = CurrencyFormatter.parseFormatted(_amountCtrl.text);
    if (amount == null || amount <= 0) return;

    setState(() => _isSubmitting = true);
    final provider = context.read<SavingsProvider>();
    final success = await provider.createDeposit(
      goalId: widget.goalId,
      amount: amount,
      term: _selectedTerm,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deposit created successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Failed to create deposit')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Title ──────────────────────────────────────
            Text(
              'New Deposit',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Amount Input ─────────────────────────────
            TextFormField(
              controller: _amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                CurrencyInputFormatter(),
              ],
              decoration: const InputDecoration(
                labelText: 'Deposit amount (VND)',
                hintText: '5.000.000',
                suffixText: 'VND',
              ),
              onChanged: (_) => _loadPreview(),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Term Selector ────────────────────────────
            Text(
              'Select term',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _terms.map((t) {
                final days = t['days'] as int;
                final label = t['label'] as String;
                final selected = _selectedTerm == days;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  selectedColor: colorScheme.primary.withOpacity(0.15),
                  labelStyle: TextStyle(
                    color: selected ? colorScheme.primary : colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  side: BorderSide(
                    color: selected ? colorScheme.primary : colorScheme.outlineVariant,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  onSelected: (_) {
                    setState(() => _selectedTerm = days);
                    _loadPreview();
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Interest Preview ─────────────────────────
            if (_loadingPreview)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_preview != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Interest Preview',
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _PreviewRow(
                      label: 'Annual Rate',
                      value: '${(_preview!['annualRate'] as num?)?.toStringAsFixed(1) ?? '0'}%',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    _PreviewRow(
                      label: 'Estimated Interest',
                      value: CurrencyFormatter.formatVND(
                        (_preview!['estimatedInterest'] as num?)?.toDouble() ?? 0,
                      ),
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                    _PreviewRow(
                      label: 'Term',
                      value: _preview!['termLabel'] as String? ?? '',
                      colorScheme: colorScheme,
                      textTheme: textTheme,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.xl),

            // ── Submit ───────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm Deposit'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final String label;
  final String value;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _PreviewRow({
    required this.label,
    required this.value,
    required this.colorScheme,
    required this.textTheme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onTertiaryContainer),
          ),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onTertiaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
