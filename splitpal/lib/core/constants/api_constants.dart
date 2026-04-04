import 'package:flutter_dotenv/flutter_dotenv.dart';

// API Constants
class ApiConstants {
  // Base URLs
    // Priority: .env API_BASE_URL -> --dart-define API_BASE_URL -> emulator default
    static const String _fallbackBaseUrl = String.fromEnvironment(
        'API_BASE_URL',
        defaultValue: 'http://10.0.2.2:8080',
    );
    static String get baseUrl {
        final envBaseUrl = dotenv.env['API_BASE_URL']?.trim();
        if (envBaseUrl != null && envBaseUrl.isNotEmpty) {
            return envBaseUrl;
        }
        return _fallbackBaseUrl;
    }
  static const String apiPrefix = '/api';
    static String get apiBaseUrl => '$baseUrl$apiPrefix';

  // WebSocket
    static String get socketUrl => baseUrl;

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
  static const String notificationPreferences =
      '/accounts/notification-preferences';

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

  // AI Endpoints
  static const String aiExtractInvoice = '/ai/extract-invoice';

  // Transaction Endpoints
  static const String transactions = '/transactions';
  static String transactionById(String id) => '/transactions/$id';
  static const String transactionSummary = '/transactions/summary';

  // Dashboard
  static const String dashboardHome = '/dashboard/home';
  static String dashboardGroup(String groupId) => '/dashboard/group/$groupId';

  // Chat Endpoints
  static String chatMessages(String groupId) =>
      '/chat/groups/$groupId/messages';

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
