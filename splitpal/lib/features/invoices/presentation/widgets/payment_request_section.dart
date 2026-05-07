import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/constants/app_constants.dart';
import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/widgets/app_card.dart';

import 'package:splitpal/features/auth/auth_provider.dart';
import 'package:splitpal/models/invoice.dart';
import 'package:splitpal/features/invoices/presentation/pages/payment_request_detail_page.dart';
import 'package:splitpal/features/invoices/presentation/widgets/transfer_payment_bottom_sheet.dart';
import 'package:splitpal/features/invoices/presentation/widgets/transfer_detail_bottom_sheet.dart';
import 'package:splitpal/features/invoices/invoice_provider.dart';

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
          if (request.expiresAt != null) ...[
            Text(
              _formatExpiry(request.expiresAt!),
              style: textTheme.bodySmall?.copyWith(
                color: request.expiresAt!.isBefore(DateTime.now())
                    ? scheme.error
                    : scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
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
      onTap: () {
        TransferDetailBottomSheet.show(
          context,
          transfer: transfer,
          groupId: widget.groupId,
          currency: currency,
        );
      },
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
                showTransferPaymentBottomSheet(
                  context,
                  transfer: transfer,
                  groupId: widget.groupId,
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

  String _formatExpiry(DateTime expiresAt) {
    final now = DateTime.now();
    if (expiresAt.isBefore(now)) {
      return 'Expired';
    }
    final diff = expiresAt.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    if (days > 0) {
      return 'Expires in $days d ${hours} h';
    }
    if (hours > 0) {
      return 'Expires in $hours h ${minutes} m';
    }
    return 'Expires in ${diff.inMinutes} m';
  }
}
