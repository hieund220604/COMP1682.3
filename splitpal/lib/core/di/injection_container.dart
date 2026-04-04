import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';

import '../../features/auth/data/datasources/auth_remote_data_source.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/domain/usecases/get_current_user.dart';
import '../../features/auth/domain/usecases/login.dart';
import '../../features/auth/domain/usecases/logout.dart';
import '../../features/auth/domain/usecases/signup.dart';
import '../../features/auth/domain/usecases/update_profile.dart';
import '../../features/auth/domain/usecases/resend_otp.dart';
import '../../features/auth/domain/usecases/verify_otp.dart';
import '../../features/auth/domain/usecases/initiate_change_password.dart';
import '../../features/auth/domain/usecases/confirm_change_password.dart';
import '../../features/auth/domain/usecases/contact_us.dart';
import '../../features/auth/domain/usecases/setup_2fa.dart';
import '../../features/auth/domain/usecases/verify_setup_2fa.dart';
import '../../features/auth/domain/usecases/verify_2fa_login.dart';
import '../../features/auth/domain/usecases/disable_2fa.dart';
import '../../features/auth/domain/usecases/get_2fa_status.dart';
import '../../features/groups/data/datasources/group_remote_data_source.dart';
import '../../features/groups/data/repositories/group_repository_impl.dart';
import '../../features/groups/domain/repositories/group_repository.dart';
import '../../features/groups/domain/usecases/get_user_groups.dart';
import '../../features/groups/domain/usecases/get_pending_invites.dart';
import '../../features/groups/domain/usecases/create_group.dart';
import '../../features/groups/domain/usecases/get_group_details.dart';
import '../../features/groups/domain/usecases/get_group_members.dart';
import '../../features/groups/domain/usecases/create_invite.dart';
import '../../features/groups/domain/usecases/accept_invite.dart';
import '../../features/groups/domain/usecases/get_group_balance.dart';
import '../../features/groups/presentation/providers/group_provider.dart';
import '../../features/subscriptions/data/datasources/subscription_remote_data_source.dart';
import '../../features/subscriptions/data/repositories/subscription_repository_impl.dart';
import '../../features/subscriptions/domain/repositories/subscription_repository.dart';
import '../../features/subscriptions/domain/usecases/get_subscriptions.dart';
import '../../features/subscriptions/domain/usecases/get_subscription_detail.dart';
import '../../features/subscriptions/domain/usecases/create_subscription.dart';
import '../../features/subscriptions/domain/usecases/cancel_subscription.dart';
import '../../features/subscriptions/domain/usecases/resume_subscription.dart';
import '../../features/subscriptions/domain/usecases/leave_subscription.dart';
import '../../features/subscriptions/domain/usecases/get_billing_history.dart';
import '../../features/subscriptions/domain/usecases/process_charges.dart';
import '../../features/subscriptions/presentation/providers/subscription_provider.dart';
import '../../features/invoices/data/datasources/invoice_remote_datasource.dart';
import '../../features/invoices/data/repositories/invoice_repository_impl.dart';
import '../../features/invoices/domain/repositories/invoice_repository.dart';
import '../../features/invoices/domain/usecases/create_invoice.dart';
import '../../features/invoices/domain/usecases/get_invoices.dart';
import '../../features/invoices/domain/usecases/get_invoice_by_id.dart';
import '../../features/invoices/domain/usecases/submit_invoice.dart';
import '../../features/invoices/domain/usecases/create_payment_request.dart';
import '../../features/invoices/domain/usecases/get_payment_requests.dart';
import '../../features/invoices/domain/usecases/cancel_payment_request.dart';
import '../../features/invoices/domain/usecases/cancel_transfer.dart';
import '../../features/invoices/domain/usecases/get_my_transfers.dart';
import '../../features/invoices/domain/usecases/initiate_payment.dart';
import '../../features/invoices/domain/usecases/verify_otp_and_pay.dart';
import '../../features/invoices/domain/usecases/get_my_balance.dart';
import '../../features/invoices/domain/services/gemini_ocr_service.dart';
import '../../features/invoices/domain/services/gemini_debt_reminder_service.dart';
import '../../features/invoices/presentation/providers/invoice_provider.dart';
import '../../features/invoices/presentation/providers/ocr_provider.dart';
import '../../features/notifications/data/datasources/notification_local_data_source.dart';
import '../../features/notifications/data/datasources/notification_remote_data_source.dart';
import '../../features/notifications/data/repositories/notification_repository_impl.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/notifications/presentation/providers/notification_provider.dart';
import '../../features/chat/data/datasources/chat_remote_data_source.dart';
import '../../features/chat/presentation/providers/chat_provider.dart';
import '../../features/exchange/data/datasources/exchange_remote_datasource.dart';
import '../../features/exchange/data/repositories/exchange_repository_impl.dart';
import '../../features/exchange/domain/repositories/exchange_repository.dart';
import '../../features/exchange/presentation/providers/exchange_provider.dart';
import '../../features/receipts/data/datasources/receipt_remote_datasource.dart';
import '../../features/receipts/data/repositories/receipt_repository_impl.dart';
import '../../features/receipts/domain/repositories/receipt_repository.dart';
import '../../features/receipts/domain/usecases/create_receipt.dart';
import '../../features/receipts/domain/usecases/create_tag.dart';
import '../../features/receipts/domain/usecases/delete_receipt.dart';
import '../../features/receipts/domain/usecases/delete_tag.dart';
import '../../features/receipts/domain/usecases/get_day_receipts.dart';
import '../../features/receipts/domain/usecases/get_month_summary.dart';
import '../../features/receipts/domain/usecases/get_tags.dart';
import '../../features/receipts/domain/usecases/update_receipt.dart';
import '../../features/receipts/domain/usecases/update_tag.dart';
import '../../features/receipts/presentation/providers/receipt_provider.dart';
import '../utils/upload_repository.dart';
import '../network/dio_client.dart';
import '../network/socket_client.dart';
import '../utils/token_manager.dart';
import '../config/gemini_config.dart';

// Service locator instance
final sl = GetIt.instance;

Future<void> init() async {
  // ============================================================
  // Core
  // ============================================================

  // External dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);

  const flutterSecureStorage = FlutterSecureStorage();
  sl.registerLazySingleton(() => flutterSecureStorage);

  // Token Manager
  sl.registerLazySingleton<TokenManager>(
    () => TokenManager(
      secureStorage: sl(),
      prefs: sl(),
    ),
  );

  // Dio Client
  sl.registerLazySingleton<DioClient>(
    () => DioClient(tokenManager: sl()),
  );

  // Socket Client
  sl.registerLazySingleton<SocketClient>(
    () => SocketClient(tokenManager: sl()),
  );

  // ============================================================
  // Features
  // ============================================================

  _initAuth();
  _initGroup();
  _initSubscription();
  _initInvoice();
  _initNotification();
  _initChat();
  _initExchange();
  _initReceipt();
}

// ============================================================
// Auth Feature
// ============================================================
void _initAuth() {
  // Data sources
  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(dioClient: sl()),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(
      remoteDataSource: sl(),
      tokenManager: sl(),
    ),
  );

  // Use cases
  sl.registerLazySingleton(() => LoginUseCase(sl()));
  sl.registerLazySingleton(() => SignUpUseCase(sl()));
  sl.registerLazySingleton(() => VerifyOTPUseCase(sl()));
  sl.registerLazySingleton(() => ResendOTPUseCase(sl()));
  sl.registerLazySingleton(() => LogoutUseCase(sl()));
  sl.registerLazySingleton(() => GetCurrentUserUseCase(sl()));
  sl.registerLazySingleton(() => UpdateProfileUseCase(sl()));
  sl.registerLazySingleton(() => InitiateChangePasswordUseCase(sl()));
  sl.registerLazySingleton(() => ConfirmChangePasswordUseCase(sl()));
  sl.registerLazySingleton(() => ContactUsUseCase(sl()));
  sl.registerLazySingleton(() => Setup2FAUseCase(sl()));
  sl.registerLazySingleton(() => VerifySetup2FAUseCase(sl()));
  sl.registerLazySingleton(() => Verify2FALoginUseCase(sl()));
  sl.registerLazySingleton(() => Disable2FAUseCase(sl()));
  sl.registerLazySingleton(() => Get2FAStatusUseCase(sl()));

  // Providers (as factories for new instances)
  sl.registerFactory(
    () => AuthProvider(
      loginUseCase: sl(),
      signUpUseCase: sl(),
      verifyOTPUseCase: sl(),
      resendOTPUseCase: sl(),
      logoutUseCase: sl(),
      getCurrentUserUseCase: sl(),
      updateProfileUseCase: sl(),
      initiateChangePasswordUseCase: sl(),
      confirmChangePasswordUseCase: sl(),
      contactUsUseCase: sl(),
      setup2FAUseCase: sl(),
      verifySetup2FAUseCase: sl(),
      verify2FALoginUseCase: sl(),
      disable2FAUseCase: sl(),
      get2FAStatusUseCase: sl(),
    ),
  );
}

// ============================================================
// Group Feature
// ============================================================
void _initGroup() {
  // Data sources
  sl.registerLazySingleton<GroupRemoteDataSource>(
    () => GroupRemoteDataSourceImpl(sl()),
  );

  // Repositories
  sl.registerLazySingleton<GroupRepository>(
    () => GroupRepositoryImpl(sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetUserGroups(sl()));
  sl.registerLazySingleton(() => GetPendingInvites(sl()));
  sl.registerLazySingleton(() => CreateGroup(sl()));
  sl.registerLazySingleton(() => GetGroupDetails(sl()));
  sl.registerLazySingleton(() => GetGroupMembers(sl()));
  sl.registerLazySingleton(() => CreateInvite(sl()));
  sl.registerLazySingleton(() => AcceptInvite(sl()));
  sl.registerLazySingleton(() => GetGroupBalance(sl()));

  // Providers
  sl.registerFactory(
    () => GroupProvider(
      getUserGroups: sl(),
      getPendingInvites: sl(),
      createGroupUseCase: sl(),
      getGroupDetails: sl(),
      getGroupMembers: sl(),
      createInvite: sl(),
      acceptInvite: sl(),
      getGroupBalance: sl(),
      groupRepository: sl(),
    ),
  );
}

// ============================================================
// Subscription Feature
// ============================================================
void _initSubscription() {
  // Data source
  sl.registerLazySingleton<SubscriptionRemoteDataSource>(
    () => SubscriptionRemoteDataSourceImpl(sl()),
  );

  // Repository
  sl.registerLazySingleton<SubscriptionRepository>(
    () => SubscriptionRepositoryImpl(sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetSubscriptions(sl()));
  sl.registerLazySingleton(() => GetSubscriptionDetail(sl()));
  sl.registerLazySingleton(() => CreateSubscription(sl()));
  sl.registerLazySingleton(() => CancelSubscription(sl()));
  sl.registerLazySingleton(() => ResumeSubscription(sl()));
  sl.registerLazySingleton(() => LeaveSubscription(sl()));
  sl.registerLazySingleton(() => GetBillingHistory(sl()));
  sl.registerLazySingleton(() => ProcessCharges(sl()));

  // Provider
  sl.registerFactory(
    () => SubscriptionProvider(
      getSubscriptions: sl(),
      getSubscriptionDetail: sl(),
      createSubscription: sl(),
      cancelSubscription: sl(),
      resumeSubscription: sl(),
      leaveSubscription: sl(),
      getBillingHistory: sl(),
      processCharges: sl(),
    ),
  );
}

// ============================================================
// Invoice Feature
// ============================================================
void _initInvoice() {
  // Data source
  sl.registerLazySingleton<InvoiceRemoteDataSource>(
    () => InvoiceRemoteDataSourceImpl(dioClient: sl()),
  );

  // Repository
  sl.registerLazySingleton<InvoiceRepository>(
    () => InvoiceRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => CreateInvoice(sl()));
  sl.registerLazySingleton(() => GetInvoices(sl()));
  sl.registerLazySingleton(() => GetInvoiceById(sl()));
  sl.registerLazySingleton(() => SubmitInvoice(sl()));
  sl.registerLazySingleton(() => CreatePaymentRequest(sl()));
  sl.registerLazySingleton(() => GetPaymentRequests(sl()));
  sl.registerLazySingleton(() => CancelPaymentRequest(sl()));
  sl.registerLazySingleton(() => CancelTransfer(sl()));
  sl.registerLazySingleton(() => GetMyTransfers(sl()));
  sl.registerLazySingleton(() => InitiatePayment(sl()));
  sl.registerLazySingleton(() => VerifyOTPAndPay(sl()));
  sl.registerLazySingleton(() => GetMyBalance(sl()));

  // Provider
  sl.registerFactory(
    () => InvoiceProvider(
      createInvoiceUseCase: sl(),
      getInvoicesUseCase: sl(),
      getInvoiceByIdUseCase: sl(),
      submitInvoiceUseCase: sl(),
      createPaymentRequestUseCase: sl(),
      getPaymentRequestsUseCase: sl(),
      cancelPaymentRequestUseCase: sl(),
      cancelTransferUseCase: sl(),
      getMyTransfersUseCase: sl(),
      initiatePaymentUseCase: sl(),
      verifyOTPAndPayUseCase: sl(),
      getMyBalanceUseCase: sl(),
    ),
  );

  // Gemini OCR Service & Provider
  if (GeminiConfig.isConfigured) {
    sl.registerLazySingleton<GeminiOcrService>(
      () => GeminiOcrService(apiKey: GeminiConfig.apiKey),
    );
    
    sl.registerFactory<OcrProvider>(
      () => OcrProvider(geminiService: sl()),
    );

    sl.registerLazySingleton<GeminiDebtReminderService>(
      () => GeminiDebtReminderService(apiKey: GeminiConfig.apiKey),
    );
  }
}

// ============================================================
// Notification Feature
// ============================================================
void _initNotification() {
  // Data sources
  sl.registerLazySingleton<NotificationRemoteDataSource>(
    () => NotificationRemoteDataSourceImpl(sl()),
  );
  
  sl.registerLazySingleton<NotificationLocalDataSource>(
    () => NotificationLocalDataSourceImpl(sl()),
  );

  // Repository
  sl.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(
      remoteDataSource: sl(),
      localDataSource: sl(),
    ),
  );

  // Provider
  sl.registerFactory(
    () => NotificationProvider(sl()),
  );
}

// ============================================================
// Chat Feature
// ============================================================
void _initChat() {
  // Data source
  sl.registerLazySingleton<ChatRemoteDataSource>(
    () => ChatRemoteDataSourceImpl(dioClient: sl()),
  );

  // Provider (factory — new instance per group chat screen)
  sl.registerFactory(
    () => ChatProvider(
      remoteDataSource: sl(),
      socketClient: sl(),
      tokenManager: sl(),
    ),
  );
}

// ============================================================
// Exchange Rate Feature
// ============================================================
void _initExchange() {
  // Data source
  sl.registerLazySingleton<ExchangeRemoteDataSource>(
    () => ExchangeRemoteDataSourceImpl(dioClient: sl()),
  );

  // Repository
  sl.registerLazySingleton<ExchangeRepository>(
    () => ExchangeRepositoryImpl(remoteDataSource: sl()),
  );

  // Provider
  sl.registerFactory(
    () => ExchangeProvider(repository: sl()),
  );
}

// ============================================================
// Receipt Diary Feature
// ============================================================
void _initReceipt() {
  // Data source
  sl.registerLazySingleton<ReceiptRemoteDataSource>(
    () => ReceiptRemoteDataSourceImpl(dioClient: sl()),
  );

  // Repository
  sl.registerLazySingleton<ReceiptRepository>(
    () => ReceiptRepositoryImpl(remoteDataSource: sl()),
  );

  // Use cases
  sl.registerLazySingleton(() => GetMonthSummary(sl()));
  sl.registerLazySingleton(() => GetDayReceipts(sl()));
  sl.registerLazySingleton(() => CreateReceipt(sl()));
  sl.registerLazySingleton(() => UpdateReceipt(sl()));
  sl.registerLazySingleton(() => DeleteReceipt(sl()));
  sl.registerLazySingleton(() => GetTags(sl()));
  sl.registerLazySingleton(() => CreateTag(sl()));
  sl.registerLazySingleton(() => UpdateTag(sl()));
  sl.registerLazySingleton(() => DeleteTag(sl()));

  // Provider
  sl.registerFactory(
    () => ReceiptProvider(
      getMonthSummaryUseCase: sl(),
      getDayReceiptsUseCase: sl(),
      createReceiptUseCase: sl(),
      updateReceiptUseCase: sl(),
      deleteReceiptUseCase: sl(),
      getTagsUseCase: sl(),
      createTagUseCase: sl(),
      updateTagUseCase: sl(),
      deleteTagUseCase: sl(),
      uploadRepository: UploadRepository(dioClient: sl()),
    ),
  );
}
