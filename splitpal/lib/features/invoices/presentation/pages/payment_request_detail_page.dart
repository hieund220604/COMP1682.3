import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/constants/app_constants.dart';
import 'package:splitpal/core/di/injection_container.dart';
import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/network/dio_client.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/currency_formatter.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/core/widgets/app_empty_state.dart';
import 'package:splitpal/core/widgets/app_section_header.dart';
import 'package:splitpal/features/invoices/domain/entities/invoice.dart';
import 'package:splitpal/features/invoices/domain/repositories/invoice_repository.dart';
import 'package:splitpal/features/invoices/presentation/pages/invoice_detail_page.dart';
import 'package:splitpal/features/invoices/presentation/providers/invoice_provider.dart';

class PaymentRequestDetailPage extends StatefulWidget {
  final String groupId;
  final String requestId;
  final String? groupName;
  final String? currency;

  const PaymentRequestDetailPage({
    super.key,
    required this.groupId,
    required this.requestId,
    this.groupName,
    this.currency,
  });

  @override
  State<PaymentRequestDetailPage> createState() =>
      _PaymentRequestDetailPageState();
}

class _PaymentRequestDetailPageState extends State<PaymentRequestDetailPage> {
  late Future<_LoadedPaymentRequestDetail> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_LoadedPaymentRequestDetail> _load() async {
    final dio = sl<DioClient>();
    final repo = sl<InvoiceRepository>();

    final response =
        await dio.get('/payment-requests/${widget.groupId}/${widget.requestId}');
    final raw = response.data;
    final data = (raw is Map<String, dynamic>) ? raw['data'] : null;
    if (data is! Map) {
      throw Exception('Invalid payment request response');
    }

    final detail = _PaymentRequestDetail.fromJson(
      Map<String, dynamic>.from(data as Map),
    );

    String? invoicesError;
    List<Invoice> sourceInvoices = const [];
    final invoicesEither = await repo.getInvoices(widget.groupId, status: 'LOCKED');
    invoicesEither.fold(
      (failure) => invoicesError = failure.message,
      (invoices) {
        sourceInvoices = invoices
            .where((i) => i.paymentRequestId == widget.requestId)
            .toList(growable: false);
      },
    );

    return _LoadedPaymentRequestDetail(
      detail: detail,
      sourceInvoices: sourceInvoices,
      invoicesError: invoicesError,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: FutureBuilder<_LoadedPaymentRequestDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverAppBar.large(
                  leading: IconButton(
                    tooltip: 'Back',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(AppIcons.back),
                  ),
                  title: const Text('Payment request'),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    icon: AppIcons.info,
                    title: 'Could not load payment request',
                    message: snapshot.error.toString(),
                    actionLabel: 'Retry',
                    onAction: () => setState(() => _future = _load()),
                  ),
                ),
              ],
            );
          }

          final loaded = snapshot.requireData;
          final detail = loaded.detail;

          final title = widget.groupName?.trim().isNotEmpty == true
              ? '${widget.groupName} · Payment request'
              : 'Payment request';

          final totalTransfers = detail.totalTransfers;
          final completedTransfers = detail.completedTransfers;
          final progress = totalTransfers <= 0
              ? 0.0
              : (completedTransfers / totalTransfers).clamp(0.0, 1.0);

          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar.large(
                title: Text(title),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.lg,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Request #${detail.id.substring(0, detail.id.length >= 8 ? 8 : detail.id.length)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                            ),
                            _StatusChip(status: detail.status),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          _fmtMoney(
                            detail.totalAmount,
                            currency: widget.currency,
                          ),
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Issued: ${_fmtDateTime(detail.issuedAt)}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                        if (detail.expiresAt != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            detail.expiresAt!.isBefore(DateTime.now())
                                ? 'Expired at ${_fmtDateTime(detail.expiresAt!)}'
                                : 'Expires: ${_fmtDateTime(detail.expiresAt!)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: detail.expiresAt!.isBefore(DateTime.now())
                                      ? scheme.error
                                      : scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Icon(AppIcons.invoices,
                                size: 18, color: scheme.onSurfaceVariant),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${detail.invoiceIds.length} invoices',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            Icon(AppIcons.payments,
                                size: 18, color: scheme.onSurfaceVariant),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '$completedTransfers/$totalTransfers transfers paid',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadii.pill),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor:
                                scheme.outlineVariant.withAlpha(80),
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              SliverToBoxAdapter(
                child: AppSectionHeader(
                  title: 'Sources (Invoices)',
                  subtitle:
                      'This payment request is generated from submitted invoices (now locked).',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverToBoxAdapter(
                  child: _SourcesCard(
                    invoices: loaded.sourceInvoices,
                    invoiceIds: detail.invoiceIds,
                    invoicesError: loaded.invoicesError,
                    groupId: widget.groupId,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              SliverToBoxAdapter(
                child: AppSectionHeader(
                  title: 'Breakdown',
                  subtitle:
                      'Who pays who, and which invoices contributed to each user balance.',
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverList.separated(
                  itemCount: detail.userBreakdowns.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    return _UserBreakdownCard(
                      breakdown: detail.userBreakdowns[index],
                      currency: widget.currency,
                    );
                  },
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.lg)),
              const SliverToBoxAdapter(
                child: AppSectionHeader(title: 'Transfers'),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverList.separated(
                  itemCount: detail.transfers.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    return _TransferCard(
                      transfer: detail.transfers[index],
                      currency: widget.currency,
                    );
                  },
                ),
              ),
              // Cancel button (only for ISSUED or PARTIALLY_PAID)
              if (detail.status == 'ISSUED' || detail.status == 'PARTIALLY_PAID')
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.xl,
                    AppSpacing.lg,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: _CancelRequestButton(
                      groupId: widget.groupId,
                      requestId: widget.requestId,
                      status: detail.status,
                      hasCompletedTransfers: detail.completedTransfers > 0,
                      onCancelled: () {
                        setState(() => _future = _load());
                      },
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 140)),
            ],
          );
        },
      ),
    );
  }
}

class _LoadedPaymentRequestDetail {
  final _PaymentRequestDetail detail;
  final List<Invoice> sourceInvoices;
  final String? invoicesError;

  const _LoadedPaymentRequestDetail({
    required this.detail,
    required this.sourceInvoices,
    required this.invoicesError,
  });
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final normalized = status.toUpperCase();
    final (label, color) = switch (normalized) {
      'ISSUED' => ('Issued', scheme.primary),
      'PARTIALLY_PAID' => ('Partially paid', scheme.secondary),
      'PAID' => ('Paid', scheme.tertiary),
      'CANCELLED' => ('Cancelled', scheme.onSurfaceVariant),
      _ => (normalized, scheme.onSurfaceVariant),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w900,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _SourcesCard extends StatelessWidget {
  final List<Invoice> invoices;
  final List<String> invoiceIds;
  final String? invoicesError;
  final String groupId;

  const _SourcesCard({
    required this.invoices,
    required this.invoiceIds,
    required this.invoicesError,
    required this.groupId,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (invoicesError != null) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          invoicesError!,
          style: textTheme.bodyMedium?.copyWith(color: scheme.error),
        ),
      );
    }

    if (invoiceIds.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'No invoices were attached to this request.',
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    if (invoices.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Invoices are locked, but details are not available in-app yet.',
          style: textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
      );
    }

    final df = DateFormat(AppConstants.displayDateFormat);

    return Column(
      children: [
        for (final inv in invoices) ...[
          AppCard(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => InvoiceDetailPage(
                    groupId: groupId,
                    invoiceId: inv.id,
                  ),
                ),
              );
            },
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    border: Border.all(color: scheme.primary.withAlpha(50)),
                  ),
                  child: Icon(AppIcons.invoices, color: scheme.primary),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        df.format(inv.invoiceDate),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        CurrencyFormatter.formatCurrency(
                          inv.amountTotal,
                          inv.currency,
                        ),
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Icon(AppIcons.chevronRight, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}

class _UserBreakdownCard extends StatelessWidget {
  final _UserPaymentBreakdown breakdown;
  final String? currency;

  const _UserBreakdownCard({
    required this.breakdown,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final isOwing = breakdown.netBalance < 0;
    final color = isOwing ? scheme.primary : scheme.tertiary;
    final sign = isOwing ? '-' : '+';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: scheme.surfaceContainerLowest,
                backgroundImage: breakdown.user.avatarUrl == null
                    ? null
                    : NetworkImage(breakdown.user.avatarUrl!),
                child: breakdown.user.avatarUrl == null
                    ? Icon(AppIcons.person, color: scheme.onSurfaceVariant)
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  breakdown.user.displayName ?? 'User',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '$sign${_fmtMoney(breakdown.netBalance.abs(), currency: currency)}',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (breakdown.debts.isEmpty)
            Text(
              'No invoice breakdown available.',
              style:
                  textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            )
          else
            Column(
              children: [
                for (final d in breakdown.debts) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      border: Border.all(
                        color: scheme.outlineVariant.withAlpha(140),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.invoiceTitle,
                                style: textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'To: ${d.creditor.displayName ?? 'User'}',
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _fmtMoney(d.remainingAmount, currency: currency),
                              style: textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'of ${_fmtMoney(d.originalAmount, currency: currency)}',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  final _TransferSummary transfer;
  final String? currency;

  const _TransferCard({
    required this.transfer,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final status = transfer.status.toUpperCase();
    final (label, color) = switch (status) {
      'COMPLETED' => ('Paid', scheme.tertiary),
      'PENDING' => ('Pending', scheme.primary),
      'FAILED' => ('Failed', scheme.error),
      'CANCELLED' => ('Cancelled', scheme.onSurfaceVariant),
      _ => (status, scheme.onSurfaceVariant),
    };

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(18),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: color.withAlpha(50)),
            ),
            child: Icon(
              status == 'COMPLETED' ? AppIcons.checkCircle : AppIcons.payments,
              color: color,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${transfer.fromUser.displayName ?? 'User'} → ${transfer.toUser.displayName ?? 'User'}',
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(color: color),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _fmtMoney(transfer.amount, currency: currency),
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              if (transfer.hasCurrencyConversion) ...[
                const SizedBox(height: 2),
                Text(
                  '${_fmtMoney(transfer.originalAmount!, currency: transfer.originalCurrency)} ${transfer.originalCurrency}',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _fmtDateTime(DateTime dt) {
  return DateFormat(AppConstants.displayDateTimeFormat).format(dt);
}

String _fmtMoney(double amount, {String? currency}) {
  if (currency == null || currency.trim().isEmpty) {
    return CurrencyFormatter.formatVND(amount);
  }
  return CurrencyFormatter.formatCurrency(amount, currency);
}

class _CancelRequestButton extends StatefulWidget {
  final String groupId;
  final String requestId;
  final String status;
  final bool hasCompletedTransfers;
  final VoidCallback onCancelled;

  const _CancelRequestButton({
    required this.groupId,
    required this.requestId,
    required this.status,
    required this.hasCompletedTransfers,
    required this.onCancelled,
  });

  @override
  State<_CancelRequestButton> createState() => _CancelRequestButtonState();
}

class _CancelRequestButtonState extends State<_CancelRequestButton> {
  bool _isCancelling = false;

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('Cancel Payment Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.hasCompletedTransfers) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Row(
                    children: [
                      Icon(AppIcons.info, color: scheme.onErrorContainer),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Some transfers are already completed. Cancelling will refund those payments automatically.',
                          style: TextStyle(color: scheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              const Text(
                'Are you sure you want to cancel this payment request? This will:',
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('  • Unlock all source invoices'),
              const Text('  • Cancel all pending transfers'),
              if (widget.hasCompletedTransfers)
                const Text('  • Refund all completed transfers'),
              const Text('  • Restore all debt amounts'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              child: const Text('Cancel Request'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);

    final provider = context.read<InvoiceProvider>();
    final success = await provider.cancelPaymentRequest(
      widget.groupId,
      widget.requestId,
    );

    if (mounted) {
      setState(() => _isCancelling = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment request cancelled successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCancelled();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Failed to cancel'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isCancelling ? null : _handleCancel,
        icon: _isCancelling
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.error,
                ),
              )
            : Icon(AppIcons.close, color: scheme.error),
        label: Text(
          widget.hasCompletedTransfers
              ? 'Cancel & Refund'
              : 'Cancel Request',
          style: TextStyle(color: scheme.error),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: scheme.error.withAlpha(120)),
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        ),
      ),
    );
  }
}

class _PaymentRequestDetail {
  final String id;
  final String groupId;
  final _UserSummary createdBy;
  final List<String> invoiceIds;
  final String status;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final double totalAmount;
  final int totalTransfers;
  final int completedTransfers;
  final List<_UserPaymentBreakdown> userBreakdowns;
  final List<_TransferSummary> transfers;

  const _PaymentRequestDetail({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.invoiceIds,
    required this.status,
    required this.issuedAt,
    this.expiresAt,
    required this.createdAt,
    required this.totalAmount,
    required this.totalTransfers,
    required this.completedTransfers,
    required this.userBreakdowns,
    required this.transfers,
  });

  static _PaymentRequestDetail fromJson(Map<String, dynamic> json) {
    final invoiceIdsRaw = json['invoiceIds'];
    final invoiceIds = (invoiceIdsRaw is List)
        ? invoiceIdsRaw.map((e) => e.toString()).toList()
        : <String>[];

    return _PaymentRequestDetail(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      groupId: (json['groupId'] ?? '').toString(),
      createdBy: _UserSummary.fromJson(json['createdBy']),
      invoiceIds: invoiceIds,
      status: (json['status'] ?? 'ISSUED').toString(),
      issuedAt: DateTime.tryParse((json['issuedAt'] ?? '').toString()) ??
          DateTime.now(),
      expiresAt: DateTime.tryParse((json['expiresAt'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      totalAmount: (json['totalAmount'] as num?)?.toDouble() ?? 0,
      totalTransfers: (json['totalTransfers'] as num?)?.toInt() ?? 0,
      completedTransfers: (json['completedTransfers'] as num?)?.toInt() ?? 0,
      userBreakdowns: _parseList(
        json['userBreakdowns'],
        (e) => _UserPaymentBreakdown.fromJson(e),
      ),
      transfers: _parseList(
        json['transfers'],
        (e) => _TransferSummary.fromJson(e),
      ),
    );
  }
}

class _TransferSummary {
  final String id;
  final _UserSummary fromUser;
  final _UserSummary toUser;
  final double amount;
  final String status;
  final DateTime? paidAt;
  final String? originalCurrency;
  final double? originalAmount;
  final String? convertedCurrency;
  final double? exchangeRate;

  const _TransferSummary({
    required this.id,
    required this.fromUser,
    required this.toUser,
    required this.amount,
    required this.status,
    this.paidAt,
    this.originalCurrency,
    this.originalAmount,
    this.convertedCurrency,
    this.exchangeRate,
  });

  bool get hasCurrencyConversion => originalCurrency != null && originalAmount != null;

  static _TransferSummary fromJson(dynamic raw) {
    final json = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return _TransferSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      fromUser: _UserSummary.fromJson(json['fromUser']),
      toUser: _UserSummary.fromJson(json['toUser']),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      status: (json['status'] ?? '').toString(),
      paidAt: json['paidAt'] == null ? null : DateTime.tryParse(json['paidAt'].toString()),
      originalCurrency: json['originalCurrency']?.toString(),
      originalAmount: (json['originalAmount'] as num?)?.toDouble(),
      convertedCurrency: json['convertedCurrency']?.toString(),
      exchangeRate: (json['exchangeRate'] as num?)?.toDouble(),
    );
  }
}

class _UserPaymentBreakdown {
  final _UserSummary user;
  final double netBalance;
  final List<_UserDebtBreakdown> debts;

  const _UserPaymentBreakdown({
    required this.user,
    required this.netBalance,
    required this.debts,
  });

  static _UserPaymentBreakdown fromJson(dynamic raw) {
    final json = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return _UserPaymentBreakdown(
      user: _UserSummary.fromJson(json['user']),
      netBalance: (json['netBalance'] as num?)?.toDouble() ?? 0,
      debts: _parseList(json['debts'], (e) => _UserDebtBreakdown.fromJson(e)),
    );
  }
}

class _UserDebtBreakdown {
  final String invoiceId;
  final String invoiceTitle;
  final _UserSummary creditor;
  final double originalAmount;
  final double remainingAmount;

  const _UserDebtBreakdown({
    required this.invoiceId,
    required this.invoiceTitle,
    required this.creditor,
    required this.originalAmount,
    required this.remainingAmount,
  });

  static _UserDebtBreakdown fromJson(dynamic raw) {
    final json = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return _UserDebtBreakdown(
      invoiceId: (json['invoiceId'] ?? '').toString(),
      invoiceTitle: (json['invoiceTitle'] ?? '').toString(),
      creditor: _UserSummary.fromJson(json['creditor']),
      originalAmount: (json['originalAmount'] as num?)?.toDouble() ?? 0,
      remainingAmount: (json['remainingAmount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _UserSummary {
  final String id;
  final String? displayName;
  final String? avatarUrl;

  const _UserSummary({
    required this.id,
    required this.displayName,
    required this.avatarUrl,
  });

  static _UserSummary fromJson(dynamic raw) {
    if (raw is String) {
      return _UserSummary(id: raw, displayName: null, avatarUrl: null);
    }
    final json = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    return _UserSummary(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      displayName: json['displayName']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }
}

List<T> _parseList<T>(dynamic raw, T Function(dynamic e) mapper) {
  if (raw is! List) return const [];
  return raw.map(mapper).toList(growable: false);
}
