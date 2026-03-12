import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:splitpal/core/config/gemini_config.dart';
import 'package:splitpal/core/di/injection_container.dart' as di;
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:splitpal/features/invoices/domain/entities/invoice.dart';
import 'package:splitpal/features/invoices/domain/services/gemini_debt_reminder_service.dart';

/// Bottom sheet dialog that generates AI-powered debt reminder messages
/// and optionally sends them via group chat.
class DebtReminderDialog extends StatefulWidget {
  /// The name of the person who owes money.
  final String debtorName;

  /// List of PENDING transfers from this debtor to the current user.
  final List<Transfer> transfers;

  /// Group currency.
  final String currency;

  /// Group ID for sending via chat.
  final String groupId;

  const DebtReminderDialog({
    super.key,
    required this.debtorName,
    required this.transfers,
    required this.currency,
    required this.groupId,
  });

  /// Show the dialog as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String debtorName,
    required List<Transfer> transfers,
    required String currency,
    required String groupId,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DebtReminderDialog(
        debtorName: debtorName,
        transfers: transfers,
        currency: currency,
        groupId: groupId,
      ),
    );
  }

  @override
  State<DebtReminderDialog> createState() => _DebtReminderDialogState();
}

class _DebtReminderDialogState extends State<DebtReminderDialog>
    with SingleTickerProviderStateMixin {
  String _selectedStyle = 'funny';
  String? _generatedMessage;
  String? _generatedStyleLabel;
  bool _isGenerating = false;
  bool _isSending = false;
  String? _error;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  double get _totalDebt =>
      widget.transfers.fold(0, (sum, t) => sum + t.amount);

  Future<void> _generate() async {
    if (!GeminiConfig.isConfigured) {
      setState(() => _error = 'Gemini API key chưa được cấu hình');
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
      _generatedMessage = null;
    });
    _fadeController.reset();

    try {
      final service = di.sl<GeminiDebtReminderService>();
      final debts = widget.transfers
          .map((t) => <String, dynamic>{
                'amount': t.amount,
                'currency': widget.currency,
                'reason': 'Transfer #${t.id.substring(0, t.id.length >= 6 ? 6 : t.id.length)}',
              })
          .toList();

      final message = await service.generateReminder(
        debtorName: widget.debtorName,
        debts: debts,
        style: _selectedStyle,
      );

      if (mounted) {
        setState(() {
          _generatedMessage = message;
          _generatedStyleLabel = GeminiDebtReminderService.styles[_selectedStyle];
          _isGenerating = false;
        });
        _fadeController.forward();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tạo tin nhắn: $e';
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _sendToChat() async {
    if (_generatedMessage == null || _generatedMessage!.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final chatDataSource = di.sl<ChatRemoteDataSource>();
      await chatDataSource.sendMessage(
        groupId: widget.groupId,
        content: _generatedMessage!,
        messageType: 'TEXT',
      );

      if (mounted) {
        setState(() => _isSending = false);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Đã gửi tin nhắn nhắc nợ vào group chat!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _error = 'Gửi thất bại: $e';
        });
      }
    }
  }

  void _copyToClipboard() {
    if (_generatedMessage == null) return;
    Clipboard.setData(ClipboardData(text: _generatedMessage!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Đã copy tin nhắn!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primary,
                          scheme.primary.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Nhắc Nợ',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Gửi nhắc ${widget.debtorName}',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Debt summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: scheme.primary.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long,
                        color: scheme.primary, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.transfers.length} khoản đang nợ',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.formatCurrency(
                                _totalDebt, widget.currency),
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: scheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Style selector
              Text(
                'Chọn phong cách',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GeminiDebtReminderService.styles.entries
                    .map((entry) {
                  final isSelected = _selectedStyle == entry.key;
                  return ChoiceChip(
                    label: Text(entry.value),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() {
                        _selectedStyle = entry.key;
                        // Clear old message when switching style
                        _generatedMessage = null;
                        _generatedStyleLabel = null;
                        _error = null;
                      });
                    },
                    selectedColor: scheme.primary.withOpacity(0.15),
                    labelStyle: textTheme.labelMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w500,
                      color:
                          isSelected ? scheme.primary : scheme.onSurface,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? scheme.primary
                          : scheme.outline.withOpacity(0.3),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Generate button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isGenerating ? null : _generate,
                  icon: _isGenerating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome, size: 18),
                  label: Text(_isGenerating
                      ? 'Đang tạo tin nhắn...'
                      : (_generatedMessage != null
                          ? 'Tạo lại'
                          : 'Tạo tin nhắn AI ✨')),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    textStyle: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),

              // Error message
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade700, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: textTheme.bodySmall?.copyWith(
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Generated message
              if (_generatedMessage != null) ...[
                const SizedBox(height: 16),
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: scheme.outline.withOpacity(0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.message,
                                size: 16,
                                color: scheme.onSurfaceVariant),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Tin nhắn nhắc nợ — ${_generatedStyleLabel ?? ''}',
                                style: textTheme.labelMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _generatedMessage!,
                          style: textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // Action buttons
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _copyToClipboard,
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Copy'),
                          style: OutlinedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _isSending ? null : _sendToChat,
                          icon: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send, size: 16),
                          label: Text(
                              _isSending ? 'Đang gửi...' : 'Gửi vào Group Chat'),
                          style: FilledButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
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
      ),
    );
  }
}
