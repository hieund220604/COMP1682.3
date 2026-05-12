import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';

/// Interest rate tiers matching the backend savingsService.ts INTEREST_TIERS.
class _InterestTier {
  final double minAmount;
  final int term;
  final double annualRate;

  const _InterestTier(this.minAmount, this.term, this.annualRate);
}

const _kTiers = [
  _InterestTier(0, 0, 0.5),
  _InterestTier(5000000, 0, 0.8),
  _InterestTier(50000000, 0, 1.0),
  _InterestTier(0, 30, 3.0),
  _InterestTier(5000000, 30, 3.3),
  _InterestTier(50000000, 30, 3.5),
  _InterestTier(0, 90, 3.8),
  _InterestTier(5000000, 90, 4.2),
  _InterestTier(50000000, 90, 4.5),
  _InterestTier(0, 180, 4.5),
  _InterestTier(5000000, 180, 5.0),
  _InterestTier(50000000, 180, 5.5),
  _InterestTier(0, 365, 5.5),
  _InterestTier(5000000, 365, 6.0),
  _InterestTier(50000000, 365, 6.5),
];

const _kTermLabels = {
  0: 'Flexible',
  30: '1 Month',
  90: '3 Months',
  180: '6 Months',
  365: '12 Months',
};

double _getRate(double amount, int term) {
  final matching = _kTiers
      .where((t) => t.term == term && amount >= t.minAmount)
      .toList()
    ..sort((a, b) => b.minAmount.compareTo(a.minAmount));
  return matching.isNotEmpty ? matching.first.annualRate : 0;
}

/// Interest = principal × (annualRate / 100) × (daysHeld / 365)
/// Matches backend: Math.round(amount * (annualRate / 100) * (daysForCalc / 365))
int _calcInterest(double amount, int termDays) {
  final rate = _getRate(amount, termDays);
  final days = termDays > 0 ? termDays : 30; // preview 30 days for flexible
  return (amount * (rate / 100) * (days / 365)).round();
}

/// Bottom sheet for creating a new Savings Goal.
/// The Interest Rate Preview table is interactive — tap a row to select that term.
class CreateGoalSheet extends StatefulWidget {
  const CreateGoalSheet({super.key});

  @override
  State<CreateGoalSheet> createState() => _CreateGoalSheetState();
}

class _CreateGoalSheetState extends State<CreateGoalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _targetCtrl = TextEditingController();
  String _selectedIcon = '🎯';
  bool _isSubmitting = false;
  double _previewAmount = 0;
  int? _selectedTerm; // null = no term chosen yet

  static const _iconOptions = [
    '🎯', '🏖️', '🚗', '🏠', '💻', '📱', '🎓', '💍',
    '🚑', '🎮', '✈️', '💰', '🏋️', '📚', '🎸', '👶',
  ];

  static const _termDays = [0, 30, 90, 180, 365];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  void _onAmountChanged(String _) {
    final parsed = CurrencyFormatter.parseFormatted(_targetCtrl.text);
    setState(() => _previewAmount = parsed ?? 0);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final targetAmount = CurrencyFormatter.parseFormatted(_targetCtrl.text);
    if (targetAmount == null || targetAmount <= 0) {
      setState(() => _isSubmitting = false);
      return;
    }

    // If a term is selected, compute deadline = now + term days
    String? deadline;
    if (_selectedTerm != null && _selectedTerm! > 0) {
      deadline = DateTime.now()
          .add(Duration(days: _selectedTerm!))
          .toIso8601String();
    }

    Navigator.pop(context, {
      'name': _nameCtrl.text.trim(),
      'targetAmount': targetAmount,
      'icon': _selectedIcon,
      if (deadline != null) 'deadline': deadline,
    });
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
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Title ──────────────────────────────────────
              Text(
                'Create Savings Goal',
                style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Icon Picker ────────────────────────────────
              Text(
                'Choose an icon',
                style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: _iconOptions.map((emoji) {
                  final selected = _selectedIcon == emoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIcon = emoji),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.primary.withOpacity(0.15)
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(AppRadii.sm),
                        border: selected
                            ? Border.all(color: colorScheme.primary, width: 1.5)
                            : Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Goal Name ──────────────────────────────────
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Goal name',
                  hintText: 'e.g. Vacation Fund',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter a name';
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.lg),

              // ── Target Amount ──────────────────────────────
              TextFormField(
                controller: _targetCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  CurrencyInputFormatter(),
                ],
                decoration: const InputDecoration(
                  labelText: 'Target amount (VND)',
                  hintText: '10.000.000',
                  suffixText: 'VND',
                ),
                onChanged: _onAmountChanged,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter a target';
                  final parsed = CurrencyFormatter.parseFormatted(v);
                  if (parsed == null || parsed <= 0) return 'Invalid amount';
                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Interest Rate Preview (interactive) ────────
              if (_previewAmount > 0) ...[
                _InteractiveRateTable(
                  amount: _previewAmount,
                  selectedTerm: _selectedTerm,
                  onTermSelected: (term) {
                    setState(() {
                      _selectedTerm = _selectedTerm == term ? null : term;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // ── Submit Button ──────────────────────────────
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
                      : const Text('Create Goal'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Interactive Rate Table ────────────────────────────────────────────────────
class _InteractiveRateTable extends StatelessWidget {
  final double amount;
  final int? selectedTerm;
  final ValueChanged<int> onTermSelected;

  const _InteractiveRateTable({
    required this.amount,
    required this.selectedTerm,
    required this.onTermSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Row(
              children: [
                Icon(Icons.trending_up, size: 16, color: colorScheme.tertiary),
                const SizedBox(width: 6),
                Text(
                  'Interest Rate Preview',
                  style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  'Tap to select',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Column headers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Term', style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  )),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Rate', textAlign: TextAlign.center, style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  )),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Est. Interest', textAlign: TextAlign.right, style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  )),
                ),
              ],
            ),
          ),

          const Divider(height: 1, indent: 14, endIndent: 14),

          // Rows
          ..._CreateGoalSheetState._termDays.map((term) {
            final rate = _getRate(amount, term);
            final interest = _calcInterest(amount, term);
            final label = _kTermLabels[term] ?? '${term}d';
            final isSelected = selectedTerm == term;

            return InkWell(
              onTap: () => onTermSelected(term),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primary.withOpacity(0.08)
                      : Colors.transparent,
                  border: isSelected
                      ? Border(
                          left: BorderSide(color: colorScheme.primary, width: 3),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Term label + radio indicator
                    Expanded(
                      flex: 3,
                      child: Row(
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 16,
                            color: isSelected
                                ? colorScheme.primary
                                : colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            label,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected ? colorScheme.primary : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Rate
                    Expanded(
                      flex: 2,
                      child: Text(
                        '${rate.toStringAsFixed(1)}%/yr',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    // Est. Interest (green)
                    Expanded(
                      flex: 3,
                      child: Text(
                        '+${CurrencyFormatter.formatVND(interest.toDouble())}',
                        textAlign: TextAlign.right,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.tertiary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Footnote for Flexible
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
            child: Text(
              '* Flexible: interest shown for 30-day preview',
              style: textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
