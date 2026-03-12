// API Constants
class ApiConstants {
  // Base URLs
  // NOTE: The Node server in this repo listens on port 8080 (see server/.env).
  // The Android emulator reaches the host via 10.0.2.2, so we point to 8080 here
  // to avoid connection timeouts when calling the backend from the app.
  static const String baseUrl = 'http://10.0.2.2:8080';
  static const String apiPrefix = '/api';
  static const String apiBaseUrl = '$baseUrl$apiPrefix';

  // WebSocket
  static const String socketUrl = baseUrl;

  // Auth Endpoints
  static const String authSignup = '/auth/signup';
  static const String authLogin = '/auth/login';
  static const String authVerifyOtp = '/auth/verify-otp';
  static const String authResendOtp = '/auth/resend-otp';
  static const String authForgotPassword = '/auth/forgot-password';
  static const String authVerifyResetOtp = '/auth/verify-reset-otp';
  static const String authResetPasswordToken = '/auth/reset-password-token';
  static const String authMe = '/auth/me';
  static const String authProfile = '/auth/profile';

  // 2FA Endpoints
  static const String twoFactorSetup = '/auth/2fa/setup';
  static const String twoFactorVerifySetup = '/auth/2fa/verify-setup';
  static const String twoFactorVerify = '/auth/2fa/verify';
  static const String twoFactorDisable = '/auth/2fa/disable';
  static const String twoFactorStatus = '/auth/2fa/status';

  // Group Endpoints
  static const String groups = '/groups';
  static String groupById(String id) => '/groups/$id';
  static String groupMembers(String groupId) => '/groups/$groupId/members';
  static String updateMemberRole(String groupId, String memberId) =>
      '/groups/$groupId/members/$memberId/role';
  static String removeMember(String groupId, String memberId) =>
      '/groups/$groupId/members/$memberId';
  static String leaveGroup(String groupId) => '/groups/$groupId/leave';
  static String groupBalance(String groupId) => '/groups/$groupId/balance';
  static String groupBalances(String groupId) => '/groups/$groupId/balances';
  static String groupTransactions(String groupId) =>
      '/groups/$groupId/transactions';
  static const String pendingInvites = '/groups/invites/pending';
  static String groupInvites(String groupId) => '/groups/$groupId/invites';
  static const String acceptInvite = '/groups/invites/accept';

  // Invoice Endpoints
  static String invoices(String groupId) => '/invoices/$groupId';
  static String invoiceById(String groupId, String invoiceId) =>
      '/invoices/$groupId/$invoiceId';
  static String submitInvoice(String groupId, String invoiceId) =>
      '/invoices/$groupId/$invoiceId/submit';
  static String adjustInvoice(String groupId, String invoiceId) =>
      '/invoices/$groupId/$invoiceId/adjust';
  static String myBalance(String groupId) => '/invoices/$groupId/my-balance';

  // Payment Request Endpoints
  static String paymentRequests(String groupId) =>
      '/payment-requests/$groupId';
  static String paymentRequestById(String groupId, String requestId) =>
      '/payment-requests/$groupId/$requestId';
  static String cancelPaymentRequest(String groupId, String requestId) =>
      '/payment-requests/$groupId/$requestId/cancel';

  // Transfer Endpoints
  static String myTransfers(String groupId) => '/transfers/group/$groupId';
  static String transferById(String transferId) => '/transfers/$transferId';
  static String initiatePayment(String transferId) =>
      '/transfers/$transferId/pay';
  static String verifyOtpAndPay(String transferId) =>
      '/transfers/$transferId/verify-otp';
  static String resendTransferOtp(String transferId) =>
      '/transfers/$transferId/resend-otp';

  // Account Endpoints
  static const String accountBalance = '/accounts/balance';
  static const String accountTopUp = '/accounts/top-up';
  static String completeTopUp(String topUpId) =>
      '/accounts/top-up/$topUpId/complete';

  // VNPay Endpoints
  static const String vnpayPayment = '/payments';
  static const String vnpayTopup = '/payments/topup';
  static const String vnpayReturn = '/payments/vnpay-return';
  static const String vnpayIpn = '/payments/vnpay-ipn';

  // Withdrawal Endpoints
  static const String withdrawals = '/withdrawals';
  static String withdrawalById(String withdrawalId) =>
      '/withdrawals/$withdrawalId';
  static String resendWithdrawalOtp(String withdrawalId) =>
      '/withdrawals/$withdrawalId/resend-otp';
  static String verifyWithdrawalOtp(String withdrawalId) =>
      '/withdrawals/$withdrawalId/verify-otp';

  // Subscription Endpoints
  static const String subscriptions = '/subscriptions';
  static String subscriptionById(String id) => '/subscriptions/$id';
  static String cancelSubscription(String id) => '/subscriptions/$id/cancel';
  static String pauseSubscription(String id) => '/subscriptions/$id/pause';
  static String resumeSubscription(String id) => '/subscriptions/$id/resume';
  static String leaveSubscription(String id) => '/subscriptions/$id/leave';
  static String billingHistory(String id) => '/subscriptions/$id/billing-history';
  static const String processCharges = '/subscriptions/process-charges';

  // Transaction Endpoints
  static const String transactions = '/transactions';
  static String transactionById(String id) => '/transactions/$id';
  static const String transactionSummary = '/transactions/summary';

  // Chat Endpoints
  static String chatMessages(String groupId) =>
      '/chat/groups/$groupId/messages';

  // Debt Endpoints
  static String groupDebts(String groupId) => '/groups/$groupId/debts';
  static String pendingDebts(String groupId) =>
      '/groups/$groupId/debts/pending';
  static String pendingCredits(String groupId) =>
      '/groups/$groupId/credits/pending';
  static String quickPay(String groupId) => '/groups/$groupId/debts/quick-pay';
  static String paySettlementBalance(String settlementId) =>
      '/settlements/$settlementId/pay-balance';
  static String paySettlementVnpay(String settlementId) =>
      '/settlements/$settlementId/pay-vnpay';

  // Settlement Endpoints
  static String settlements(String groupId) => '/groups/$groupId/settlements';
  static String suggestedSettlements(String groupId) =>
      '/groups/$groupId/settlements/suggested';

  // Headers
  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  static Map<String, String> authHeaders(String token) => {
        ...defaultHeaders,
        'Authorization': 'Bearer $token',
      };
}
