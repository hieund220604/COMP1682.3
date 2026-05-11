import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/api_constants.dart';
import 'package:splitpal/core/app_services.dart';
import '../../../../core/navigation/app_route_observer.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/utils/currency_formatter.dart';
import 'package:splitpal/features/auth/auth_provider.dart';
import 'home_shell_page.dart';

enum WalletOperationMode { topup, withdraw }

// --- Models & Formatters ---

class BankModel {
  final String name;
  final String fullName;
  final String logoUrl;

  const BankModel(this.name, this.fullName, this.logoUrl);
}

const _popularBanks = [
  BankModel('NCB', 'Ngân hàng TMCP Quốc Dân', 'https://cdn.vietqr.io/img/NCB.png'),
  BankModel('Vietcombank', 'Ngân hàng TMCP Ngoại Thương Việt Nam', 'https://cdn.vietqr.io/img/VCB.png'),
  BankModel('Techcombank', 'Ngân hàng TMCP Kỹ thương Việt Nam', 'https://cdn.vietqr.io/img/TCB.png'),
  BankModel('MBBank', 'Ngân hàng TMCP Quân đội', 'https://cdn.vietqr.io/img/MB.png'),
  BankModel('ACB', 'Ngân hàng TMCP Á Châu', 'https://cdn.vietqr.io/img/ACB.png'),
  BankModel('VPBank', 'Ngân hàng TMCP Việt Nam Thịnh Vượng', 'https://cdn.vietqr.io/img/VPB.png'),
  BankModel('TPBank', 'Ngân hàng TMCP Tiên Phong', 'https://cdn.vietqr.io/img/TPB.png'),
  BankModel('BIDV', 'Ngân hàng TMCP Đầu tư và Phát triển Việt Nam', 'https://cdn.vietqr.io/img/BIDV.png'),
  BankModel('VietinBank', 'Ngân hàng TMCP Công thương Việt Nam', 'https://cdn.vietqr.io/img/ICB.png'),
  BankModel('Agribank', 'Ngân hàng Nông nghiệp và Phát triển Nông thôn Việt Nam', 'https://cdn.vietqr.io/img/VBA.png')
];

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.selection.baseOffset == 0) {
      return newValue;
    }
    // Remove all dots/commas
    String newText = newValue.text.replaceAll(RegExp(r'[,.]'), '');
    if (newText.isEmpty) return newValue;
    
    int? value = int.tryParse(newText);
    if (value == null) return oldValue;
    
    // Format with dots
    final formatter = NumberFormat('#,###', 'vi_VN');
    String formatted = formatter.format(value).replaceAll(',', '.');
    
    return newValue.copyWith(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length));
  }
}

// --- Main Page ---

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
  late WalletOperationMode _currentMode;

  final _topUpAmountController = TextEditingController();

  final _withdrawAmountController = TextEditingController();
  final _withdrawTotpController = TextEditingController();
  final _withdrawOtpController = TextEditingController();

  // Withdraw Bank Info
  BankModel? _selectedBank = _popularBanks.firstWhere((b) => b.name == 'NCB');
  final _accountNumberController = TextEditingController(text: '9704198526191432198');
  final _accountNameController = TextEditingController(text: 'NGUYEN VAN A');

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

  DioClient get _dioClient => AppServices.dio;

  @override
  void initState() {
    super.initState();
    _currentMode = widget.mode;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
      if (_currentMode == WalletOperationMode.topup) {
        _topUpFocusNode.requestFocus();
      } else {
        _withdrawFocusNode.requestFocus();
      }
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
    _accountNumberController.dispose();
    _accountNameController.dispose();
    _topUpFocusNode.dispose();
    _withdrawFocusNode.dispose();
    super.dispose();
  }

  // Parses the formatted string back to a clean double
  double? _parseAmount(String text) {
    final clean = text.replaceAll(RegExp(r'[,.]'), '');
    return double.tryParse(clean);
  }

  Future<void> _startTopUp() async {
    final amount = _parseAmount(_topUpAmountController.text);
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
    final amount = _parseAmount(_withdrawAmountController.text);
    if (amount == null || amount <= 0) {
      _showSnackBar('Please enter a valid withdrawal amount.', isError: true);
      return;
    }
    
    if (_selectedBank == null || _accountNumberController.text.trim().isEmpty) {
        _showSnackBar('Please provide complete bank details.', isError: true);
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
      final payload = <String, dynamic>{
        'amount': amount,
        'bankName': _selectedBank!.name,
        'accountNumber': _accountNumberController.text.trim(),
        'accountName': _accountNameController.text.trim(),
      };

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
  
  void _showBankSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final theme = Theme.of(context);
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Destination Bank',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _popularBanks.length,
                  separatorBuilder: (_, __) => Divider(color: theme.colorScheme.outlineVariant),
                  itemBuilder: (context, index) {
                    final bank = _popularBanks[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 50,
                        height: 50,
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.colorScheme.outlineVariant),
                        ),
                        child: Center(
                          child: Image.network(
                            bank.logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                Icon(Icons.account_balance, color: theme.colorScheme.primary),
                          ),
                        ),
                      ),
                      title: Text(bank.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      subtitle: Text(bank.fullName, style: theme.textTheme.bodySmall),
                      trailing: _selectedBank?.name == bank.name 
                        ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                        : null,
                      onTap: () {
                        setState(() {
                          _selectedBank = bank;
                        });
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.watch<AuthProvider>().user;
    final currency = user?.currency ?? 'VND';
    final balance = user?.balance ?? 0;
    final requiresTotp = user?.twoFactorEnabled ?? false;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Wallet'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Balance Card Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.85)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Available Balance',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onPrimary.withOpacity(0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.formatCurrency(balance, currency),
                      style: theme.textTheme.headlineLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Animated Sliding Segmented Control
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: _SlidingSegmentedControl(
                currentMode: _currentMode,
                onModeChanged: (mode) {
                  setState(() => _currentMode = mode);
                  if (mode == WalletOperationMode.topup) {
                    _topUpFocusNode.requestFocus();
                  } else {
                    _withdrawFocusNode.requestFocus();
                  }
                },
              ),
            ),

            const SizedBox(height: 16),

            // Body Area (AnimatedSwitcher for smooth transition)
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.05),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  );
                },
                child: _currentMode == WalletOperationMode.topup
                    ? _buildTopUpView(theme)
                    : _buildWithdrawView(theme, requiresTotp),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopUpView(ThemeData theme) {
    return SingleChildScrollView(
      key: const ValueKey('topup_view'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount to Top Up',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _topUpAmountController,
            focusNode: _topUpFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(),
            ],
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: '₫ ',
              prefixStyle: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Funding Source',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.account_balance, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VNPay Gateway',
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Instant transfer',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
              ],
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _isTopUpLoading ? null : _startTopUp,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isTopUpLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Top Up Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawView(ThemeData theme, bool requiresTotp) {
    return SingleChildScrollView(
      key: const ValueKey('withdraw_view'),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount to Withdraw',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _withdrawAmountController,
            focusNode: _withdrawFocusNode,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CurrencyInputFormatter(),
            ],
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
            decoration: InputDecoration(
              hintText: '0',
              prefixText: '₫ ',
              prefixStyle: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(20),
            ),
          ),
          const SizedBox(height: 32),
          
          Text(
            'Destination Account',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          
          // Bank Selection UI
          InkWell(
            onTap: _showBankSelectionModal,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border.all(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (_selectedBank != null)
                    Container(
                      width: 40,
                      height: 40,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                      ),
                      child: Center(
                        child: Image.network(
                          _selectedBank!.logoUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(Icons.account_balance, color: theme.colorScheme.primary),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.account_balance, color: theme.colorScheme.onSurfaceVariant),
                    ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedBank?.name ?? 'Select Bank',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (_selectedBank != null)
                          Text(
                            _selectedBank!.fullName,
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _accountNumberController,
            label: 'Account Number',
            icon: Icons.numbers,
            theme: theme,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _accountNameController,
            label: 'Account Holder Name',
            icon: Icons.person,
            theme: theme,
            textCapitalization: TextCapitalization.characters,
          ),

          if (requiresTotp) ...[
            const SizedBox(height: 24),
            Text(
              'Security Verification',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _withdrawTotpController,
              label: '2FA Authenticator Code',
              icon: Icons.security,
              theme: theme,
              keyboardType: TextInputType.number,
            ),
          ],
          
          const SizedBox(height: 48),
          
          if (_activeWithdrawalId == null)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isWithdrawalLoading ? null : _initiateWithdrawal,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isWithdrawalLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Withdraw Funds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.colorScheme.primaryContainer),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.mark_email_unread, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Email Verification',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent an OTP to your email. Please enter it below to confirm this withdrawal.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _withdrawOtpController,
                    label: 'Email OTP',
                    icon: Icons.password,
                    theme: theme,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isOtpResending ? null : _resendWithdrawalOtp,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_isOtpResending ? 'Resending...' : 'Resend'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: _isOtpVerifying ? null : _verifyWithdrawalOtp,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(_isOtpVerifying ? 'Verifying...' : 'Confirm Withdrawal'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required ThemeData theme,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: theme.colorScheme.onSurfaceVariant),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}

class _SlidingSegmentedControl extends StatelessWidget {
  final WalletOperationMode currentMode;
  final ValueChanged<WalletOperationMode> onModeChanged;

  const _SlidingSegmentedControl({
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTopUp = currentMode == WalletOperationMode.topup;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.all(6),
      child: Stack(
        children: [
          // Sliding Background
          AnimatedAlign(
            alignment: isTopUp ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: FractionallySizedBox(
              widthFactor: 0.5,
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Buttons Row
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onModeChanged(WalletOperationMode.topup),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.add_circle_outline,
                            size: 18,
                            color: isTopUp ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.titleSmall!.copyWith(
                            fontWeight: isTopUp ? FontWeight.w800 : FontWeight.w600,
                            color: isTopUp ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                          child: const Text('Top Up'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onModeChanged(WalletOperationMode.withdraw),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            size: 18,
                            color: !isTopUp ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: theme.textTheme.titleSmall!.copyWith(
                            fontWeight: !isTopUp ? FontWeight.w800 : FontWeight.w600,
                            color: !isTopUp ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                          ),
                          child: const Text('Withdraw'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
