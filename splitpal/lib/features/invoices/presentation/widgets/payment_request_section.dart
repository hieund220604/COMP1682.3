import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/config/gemini_config.dart';
import 'package:splitpal/core/constants/app_constants.dart';
import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/widgets/app_card.dart';

import 'package:splitpal/features/auth/presentation/providers/auth_provider.dart';
import 'package:splitpal/features/invoices/domain/entities/invoice.dart';
import 'package:splitpal/features/invoices/presentation/pages/payment_request_detail_page.dart';
import 'package:splitpal/features/invoices/presentation/pages/transfer_payment_page.dart';
import 'package:splitpal/features/invoices/presentation/providers/invoice_provider.dart';
import 'package:splitpal/features/invoices/presentation/widgets/debt_reminder_dialog.dart';

class PaymentRequestSection extends StatefulWidget {
  final String groupId;
  final String? groupName;
  final String? currency;
  final bool isOwnerOrAdmin;
  final Future<void> Function()? onCreatePaymentRequest;

  const PaymentRequestSection({
    super.key,
    required this.groupId,
    this.groupName,
    this.currency,
    this.isOwnerOrAdmin = false,
    this.onCreatePaymentRequest,
  });

  @override
  State<PaymentRequestSection> createState() => _PaymentRequestSectionState();
}

class _PaymentRequestSectionState extends State<PaymentRequestSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<InvoiceProvider>();
    await Future.wait([
      provider.loadPaymentRequests(widget.groupId),
      provider.loadMyTransfers(widget.groupId),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final currency = widget.currency ??
        context.select((AuthProvider p) => p.user?.currency) ??
        AppConstants.defaultCurrency;

    return Consumer<InvoiceProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final activeRequest = provider.activePaymentRequest;
        final pendingTransfers = provider.myPendingTransfers;
        final completedTransfers = provider.myCompletedTransfers;

        // Get current user ID to separate outgoing vs incoming transfers
        final currentUserId = context.read<AuthProvider>().user?.id;
        // Outgoing = I owe others (fromUserId == me)
        final outgoingPending = pendingTransfers
            .where((t) => t.fromUserId == currentUserId)
            .toList();

        return RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: AppSpacing.pagePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Create Payment Request button (when no active request)
                  if (activeRequest == null &&
                      widget.isOwnerOrAdmin &&
                      widget.onCreatePaymentRequest != null) ...[              
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => widget.onCreatePaymentRequest!(),
                        icon: const Icon(AppIcons.add),
                        label: const Text('Create Payment Request'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                          textStyle: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Active Payment Request
                  if (activeRequest != null) ...[
                    Text(
                      'Active Payment Request',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _buildActivePaymentRequest(
                      context,
                      activeRequest,
                      currency: currency,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // AI Debt Reminder Section (uses ALL pendingTransfers,
                  // internally filters for incoming where toUserId == me)
                  if (GeminiConfig.isConfigured)
                    _buildDebtReminderSection(
                      context,
                      pendingTransfers,
                      currency: currency,
                    ),

                  // My Pending Transfers (only OUTGOING - transfers I owe)
                  Text(
                    'My Pending Transfers',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (outgoingPending.isEmpty)
                    _buildEmptyState(
                      context,
                      'No pending transfers',
                    )
                  else
                    ...outgoingPending.map((transfer) =>
                        _buildTransferCard(
                          context,
                          transfer,
                          currency: currency,
                        )),

                  const SizedBox(height: AppSpacing.xl),

                  // Completed Transfers
                  Text(
                    'Completed Transfers',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (completedTransfers.isEmpty)
                    _buildEmptyState(
                      context,
                      'No completed transfers',
                    )
                  else
                    ...completedTransfers.map((transfer) =>
                        _buildTransferCard(
                          context,
                          transfer,
                          currency: currency,
                        )),

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          message,
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildActivePaymentRequest(
    BuildContext context,
    PaymentRequest request, {
    required String currency,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusColor = _getRequestStatusColor(request.status);

    return AppCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentRequestDetailPage(
              groupId: widget.groupId,
              requestId: request.id,
              groupName: widget.groupName,
              currency: currency,
            ),
          ),
        );
      },
      color: scheme.primary.withAlpha(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(color: scheme.primary.withAlpha(70)),
                    ),
                    child: Icon(
                      AppIcons.payments,
                      color: scheme.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Request #${request.id.substring(0, request.id.length >= 8 ? 8 : request.id.length)}',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withAlpha(26),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: statusColor.withAlpha(80)),
                ),
                child: Text(
                  request.status,
                  style: textTheme.labelSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Issued: ${_formatDate(request.issuedAt)}',
            style: textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(
                AppIcons.invoices,
                color: scheme.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${request.invoiceIds.length} invoices locked',
                style: textTheme.bodySmall,
              ),
              const Spacer(),
              Icon(
                AppIcons.chevronRight,
                color: scheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(
    BuildContext context,
    Transfer transfer, {
    required String currency,
  }) {
    final isPaid = transfer.status == 'COMPLETED';
    final isCancelled = transfer.status == 'CANCELLED';
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final statusColor = isPaid
        ? scheme.tertiary
        : isCancelled
            ? scheme.onSurfaceVariant
            : Colors.orange;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isPaid ? AppIcons.checkCircle : AppIcons.payments,
              color: statusColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pay to ${transfer.toName.isNotEmpty ? transfer.toName : "User"}',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  CurrencyFormatter.formatCurrency(transfer.amount, currency),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (transfer.hasCurrencyConversion) ...[
                  const SizedBox(height: 2),
                  Text(
                    '≈ ${CurrencyFormatter.formatCurrency(transfer.originalAmount!, transfer.originalCurrency ?? 'USD')} ${transfer.originalCurrency}',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isPaid && !isCancelled)
            FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransferPaymentPage(
                      transfer: transfer,
                      groupId: widget.groupId,
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const Text('Pay'),
            )
          else if (isCancelled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.onSurfaceVariant.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                'CANCELLED',
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.tertiary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                'PAID',
                style: textTheme.labelMedium?.copyWith(
                  color: scheme.tertiary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getRequestStatusColor(String status) {
    switch (status) {
      case 'ISSUED':
        return Colors.orange;
      case 'PARTIALLY_PAID':
        return Colors.amber;
      case 'PAID':
        return Colors.green;
      case 'CANCELLED':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat(AppConstants.displayDateTimeFormat).format(date);
  }

  /// Builds the AI Debt Reminder section.
  /// Groups pending transfers where others owe the current user
  /// and shows an AI reminder button for each debtor.
  Widget _buildDebtReminderSection(
    BuildContext context,
    List<Transfer> pendingTransfers, {
    required String currency,
  }) {
    final currentUserId = context.read<AuthProvider>().user?.id;
    if (currentUserId == null) return const SizedBox.shrink();

    // Filter transfers where current user is the RECEIVER (others owe me)
    final transfersOwedToMe = pendingTransfers
        .where((t) => t.toUserId == currentUserId && t.status == 'PENDING')
        .toList();

    if (transfersOwedToMe.isEmpty) return const SizedBox.shrink();

    // Group by debtor (fromUserId)
    final Map<String, List<Transfer>> groupedByDebtor = {};
    for (final t in transfersOwedToMe) {
      groupedByDebtor.putIfAbsent(t.fromUserId, () => []).add(t);
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_awesome, color: scheme.primary, size: 20),
            const SizedBox(width: 6),
            Text(
              'AI Nhắc Nợ',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        ...groupedByDebtor.entries.map((entry) {
          final debtorTransfers = entry.value;
          final debtorName = debtorTransfers.first.fromName.isNotEmpty
              ? debtorTransfers.first.fromName
              : 'User';
          final totalAmount =
              debtorTransfers.fold<double>(0, (s, t) => s + t.amount);

          return AppCard(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        scheme.primary.withOpacity(0.15),
                        scheme.primary.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.person_outline,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        debtorName,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Nợ ${CurrencyFormatter.formatCurrency(totalAmount, currency)} • ${debtorTransfers.length} khoản',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    DebtReminderDialog.show(
                      context,
                      debtorName: debtorName,
                      transfers: debtorTransfers,
                      currency: currency,
                      groupId: widget.groupId,
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, size: 14),
                  label: const Text('Nhắc nợ'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}
