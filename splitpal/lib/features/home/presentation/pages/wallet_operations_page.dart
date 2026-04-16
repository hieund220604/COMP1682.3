import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/api_constants.dart';
import 'package:splitpal/core/app_services.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:splitpal/features/auth/auth_provider.dart';
import 'home_shell_page.dart';

enum WalletOperationMode { topup, withdraw }

class WalletOperationsPage extends StatefulWidget {
  const WalletOperationsPage({
    super.key,
    this.mode = WalletOperationMode.topup,
  });

  final WalletOperationMode mode;

  @override
  State<WalletOperationsPage> createState() => _WalletOperationsPageState();
}

class _WalletOperationsPageState extends State<WalletOperationsPage>
    with WidgetsBindingObserver, RouteAware {
  static const _withdrawalBank = _PinnedWithdrawalBank(
    bankName: 'NCB',
    accountNumber: '9704198526191432198',
    accountName: 'NGUYEN VAN A',
    issueDate: '07/15',
  );

  final _topUpAmountController = TextEditingController();

  final _withdrawAmountController = TextEditingController();
  final _withdrawTotpController = TextEditingController();
  final _withdrawOtpController = TextEditingController();
  final _topUpFocusNode = FocusNode();
  final _withdrawFocusNode = FocusNode();

  bool _isTopUpLoading = false;
  bool _isWithdrawalLoading = false;
  bool _isOtpVerifying = false;
  bool _isOtpResending = false;
  bool _awaitingVnpayCompletion = false;
  bool _isPollingTopUpResult = false;

  double? _topUpBalanceBefore;
  double? _pendingTopUpAmount;

  String? _activeWithdrawalId;
  ModalRoute<dynamic>? _route;
  final _listController = ScrollController();
  final _topUpSectionKey = GlobalKey();
  final _withdrawSectionKey = GlobalKey();

  DioClient get _dioClient => AppServices.dio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
      _scrollToInitialMode();
    });
  }

  Future<void> _refreshData() async {
    await context.read<AuthProvider>().getCurrentUser(silent: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      if (_route != null) {
        appRouteObserver.unsubscribe(this);
      }
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPush() {
    _refreshData();
  }

  @override
  void didPopNext() {
    _refreshData();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _awaitingVnpayCompletion) {
      _awaitingVnpayCompletion = false;
      _pollTopUpResultAfterResume();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _topUpAmountController.dispose();
    _withdrawAmountController.dispose();
    _withdrawTotpController.dispose();
    _withdrawOtpController.dispose();
    _topUpFocusNode.dispose();
    _withdrawFocusNode.dispose();
    _listController.dispose();
    super.dispose();
  }

  Future<void> _scrollToInitialMode() async {
    final key = widget.mode == WalletOperationMode.withdraw
        ? _withdrawSectionKey
        : _topUpSectionKey;
    final targetContext = key.currentContext;
    if (targetContext != null) {
      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOut,
      );
    }
    if (widget.mode == WalletOperationMode.withdraw) {
      _withdrawFocusNode.requestFocus();
    } else {
      _topUpFocusNode.requestFocus();
    }
  }

  Future<void> _startTopUp() async {
    final amount = double.tryParse(_topUpAmountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid top-up amount.', isError: true);
      return;
    }

    final currentBalance = context.read<AuthProvider>().user?.balance ?? 0;

    setState(() => _isTopUpLoading = true);
    try {
      final response = await _dioClient.post(
        ApiConstants.vnpayTopup,
        data: {'amount': amount},
      );

      final data = response.data['data'];
      final paymentUrl = data is Map<String, dynamic>
          ? data['paymentUrl'] as String?
          : null;

      if (paymentUrl == null || paymentUrl.isEmpty) {
        _showSnackBar(
          'Cannot create VNPay payment URL. Please try again.',
          isError: true,
        );
        return;
      }

      final uri = Uri.tryParse(paymentUrl);
      if (uri == null) {
        _showSnackBar('Invalid VNPay URL received from server.', isError: true);
        return;
      }

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        await _showPaymentUrlDialog(paymentUrl);
      }

      if (mounted) {
        _awaitingVnpayCompletion = true;
        _topUpBalanceBefore = currentBalance.toDouble();
        _pendingTopUpAmount = amount;
        _showSnackBar('VNPay page opened. Complete payment to finish top-up.');
      }
    } catch (e) {
      _showSnackBar(
        _errorText(e, fallback: 'Failed to start top-up.'),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isTopUpLoading = false);
      }
    }
  }

  Future<void> _pollTopUpResultAfterResume() async {
    if (_isPollingTopUpResult) return;

    final amount = _pendingTopUpAmount;
    final balanceBefore = _topUpBalanceBefore;
    if (amount == null || balanceBefore == null) {
      return;
    }

    _isPollingTopUpResult = true;
    try {
      final authProvider = context.read<AuthProvider>();
      const maxAttempts = 10;
      for (var attempt = 0; attempt < maxAttempts && mounted; attempt++) {
        await authProvider.getCurrentUser(silent: true);
        if (!mounted) return;

        final latestBalance = authProvider.user?.balance.toDouble() ?? 0;

        if (latestBalance >= (balanceBefore + amount - 0.01)) {
          _pendingTopUpAmount = null;
          _topUpBalanceBefore = null;
          _showSnackBar('Top-up successful. Your balance has been updated.');
          if (mounted) {
            Navigator.of(context).pushNamedAndRemoveUntil(
              HomeShellPage.routeName,
              (route) => false,
            );
          }
          return;
        }

        await Future.delayed(const Duration(seconds: 3));
      }

      if (mounted) {
        _showSnackBar(
          'Payment is being processed. Please pull to refresh in a few seconds.',
        );
      }
    } finally {
      _isPollingTopUpResult = false;
    }
  }

  Future<void> _initiateWithdrawal() async {
    final amount = double.tryParse(_withdrawAmountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid withdrawal amount.', isError: true);
      return;
    }

    final requiresTotp =
        context.read<AuthProvider>().user?.twoFactorEnabled ?? false;
    final totpToken = _withdrawTotpController.text.trim();
    if (requiresTotp && totpToken.isEmpty) {
      _showSnackBar('Enter your 2FA code to continue.', isError: true);
      return;
    }

    setState(() => _isWithdrawalLoading = true);
    try {
      final payload = <String, dynamic>{'amount': amount};

      if (totpToken.isNotEmpty) {
        payload['totpToken'] = totpToken;
      }

      final response = await _dioClient.post(
        ApiConstants.withdrawals,
        data: payload,
      );

      final data = response.data['data'];
      final withdrawalId = data is Map<String, dynamic>
          ? (data['id'] ?? data['_id']) as String?
          : null;

      if (withdrawalId == null || withdrawalId.isEmpty) {
        _showSnackBar(
          'Could not read withdrawal ID from server.',
          isError: true,
        );
        return;
      }

      setState(() {
        _activeWithdrawalId = withdrawalId;
      });

      _withdrawOtpController.clear();
      _showSnackBar('OTP has been sent. Please verify to complete withdrawal.');
    } catch (e) {
      final errorText = _errorText(
        e,
        fallback: 'Failed to initiate withdrawal.',
      );
      if (errorText.contains('Two-factor authentication required')) {
        _showSnackBar(
          'This account requires 2FA. Enter your authenticator code and try again.',
          isError: true,
        );
        return;
      }
      _showSnackBar(errorText, isError: true);
    } finally {
      if (mounted) {
        setState(() => _isWithdrawalLoading = false);
      }
    }
  }

  Future<void> _verifyWithdrawalOtp() async {
    final withdrawalId = _activeWithdrawalId;
    final otp = _withdrawOtpController.text.trim();
    final authProvider = context.read<AuthProvider>();

    if (withdrawalId == null || withdrawalId.isEmpty) {
      _showSnackBar('No active withdrawal to verify.', isError: true);
      return;
    }

    if (otp.isEmpty) {
      _showSnackBar('Please enter OTP.', isError: true);
      return;
    }

    setState(() => _isOtpVerifying = true);
    try {
      await _dioClient.post(
        ApiConstants.verifyWithdrawalOtp(withdrawalId),
        data: {'otp': otp},
      );

      _showSnackBar('Withdrawal completed successfully.');
      _withdrawOtpController.clear();
      setState(() => _activeWithdrawalId = null);

      await authProvider.getCurrentUser(silent: true);
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          HomeShellPage.routeName,
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar(
        _errorText(e, fallback: 'OTP verification failed.'),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isOtpVerifying = false);
      }
    }
  }

  Future<void> _resendWithdrawalOtp() async {
    final withdrawalId = _activeWithdrawalId;

    if (withdrawalId == null || withdrawalId.isEmpty) {
      _showSnackBar('No active withdrawal to resend OTP.', isError: true);
      return;
    }

    setState(() => _isOtpResending = true);
    try {
      await _dioClient.post(ApiConstants.resendWithdrawalOtp(withdrawalId));
      _showSnackBar('OTP resent. Please check your email.');
    } catch (e) {
      _showSnackBar(
        _errorText(e, fallback: 'Failed to resend OTP.'),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() => _isOtpResending = false);
      }
    }
  }

  Future<void> _showPaymentUrlDialog(String paymentUrl) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Open VNPay link'),
          content: SelectableText(paymentUrl),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: paymentUrl));
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Copy URL'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  String _errorText(Object error, {required String fallback}) {
    final text = error.toString().trim();
    if (text.isEmpty) {
      return fallback;
    }
    if (text.startsWith('Exception:')) {
      return text.replaceFirst('Exception:', '').trim();
    }
    return text;
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final currency = user?.currency ?? 'VND';
    final balance = user?.balance ?? 0;
    final requiresTotp = user?.twoFactorEnabled ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Wallet Operations')),
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<AuthProvider>().getCurrentUser(silent: true);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          controller: _listController,
          children: [
            _SectionCard(
              title: 'Current Balance',
              child: Text(
                CurrencyFormatter.formatCurrency(balance, currency),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _topUpSectionKey,
              child: _SectionCard(
                title: 'Top Up via VNPay',
                subtitle:
                    'Create VNPay payment link and complete payment in browser.',
                child: Column(
                  children: [
                    TextField(
                      controller: _topUpAmountController,
                      focusNode: _topUpFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _isTopUpLoading ? null : _startTopUp,
                        icon: _isTopUpLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.open_in_new),
                        label: Text(
                          _isTopUpLoading
                              ? 'Creating link...'
                              : 'Top Up with VNPay',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: _withdrawSectionKey,
              child: _SectionCard(
                title: 'Withdraw to NCB',
                subtitle:
                    'Withdrawals are sent only to the configured NCB account below.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BankDetailsCard(bank: _withdrawalBank),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _withdrawAmountController,
                      focusNode: _withdrawFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        prefixIcon: Icon(Icons.currency_exchange),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (requiresTotp) ...[
                      TextField(
                        controller: _withdrawTotpController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '2FA code',
                          prefixIcon: Icon(Icons.security),
                        ),
                      ),
                    ] else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '2FA is not enabled on this account.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isWithdrawalLoading
                            ? null
                            : _initiateWithdrawal,
                        child: Text(
                          _isWithdrawalLoading
                              ? 'Requesting...'
                              : 'Request withdrawal OTP',
                        ),
                      ),
                    ),
                    if (_activeWithdrawalId != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Active withdrawal: $_activeWithdrawalId',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _withdrawOtpController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'OTP from email',
                                prefixIcon: Icon(Icons.password),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: _isOtpResending
                                        ? null
                                        : _resendWithdrawalOtp,
                                    child: Text(
                                      _isOtpResending
                                          ? 'Resending...'
                                          : 'Resend OTP',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _isOtpVerifying
                                        ? null
                                        : _verifyWithdrawalOtp,
                                    child: Text(
                                      _isOtpVerifying
                                          ? 'Verifying...'
                                          : 'Verify OTP',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;

  const _SectionCard({required this.title, this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _PinnedWithdrawalBank {
  final String bankName;
  final String accountNumber;
  final String accountName;
  final String issueDate;

  const _PinnedWithdrawalBank({
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
    required this.issueDate,
  });
}

class _BankDetailsCard extends StatelessWidget {
  final _PinnedWithdrawalBank bank;

  const _BankDetailsCard({required this.bank});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surfaceContainerHighest,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_balance, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Bank details',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _Pill(label: bank.bankName),
            ],
          ),
          const SizedBox(height: 12),
          _DetailRow(label: 'Card number', value: bank.accountNumber),
          const SizedBox(height: 8),
          _DetailRow(label: 'Cardholder', value: bank.accountName),
          const SizedBox(height: 8),
          _DetailRow(label: 'Issue date', value: bank.issueDate),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 4,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 6,
          child: SelectableText(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;

  const _Pill({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
