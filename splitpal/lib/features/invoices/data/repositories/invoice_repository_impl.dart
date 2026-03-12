import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/repositories/invoice_repository.dart';
import '../datasources/invoice_remote_datasource.dart';

class InvoiceRepositoryImpl implements InvoiceRepository {
  final InvoiceRemoteDataSource remoteDataSource;

  InvoiceRepositoryImpl({required this.remoteDataSource});

  @override
  Future<Either<Failure, Invoice>> createInvoice({
    required String groupId,
    required String title,
    required double amountTotal,
    required List<InvoiceItemCreate> items,
    String? imageUrl,
    String? note,
    String? currency,
  }) async {
    try {
      final result = await remoteDataSource.createInvoice(
        groupId: groupId,
        title: title,
        amountTotal: amountTotal,
        items: items,
        imageUrl: imageUrl,
        note: note,
        currency: currency,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Invoice>>> getInvoices(String groupId, {String? status}) async {
    try {
      final result = await remoteDataSource.getInvoices(groupId, status: status);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Invoice>> getInvoiceById(String groupId, String invoiceId) async {
    try {
      final result = await remoteDataSource.getInvoiceById(groupId, invoiceId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Invoice>> updateInvoice({
    required String groupId,
    required String invoiceId,
    String? title,
    List<InvoiceItemCreate>? items,
    String? imageUrl,
    String? note,
  }) async {
    try {
      final result = await remoteDataSource.updateInvoice(
        groupId: groupId,
        invoiceId: invoiceId,
        title: title,
        items: items,
        imageUrl: imageUrl,
        note: note,
      );
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> deleteInvoice(String groupId, String invoiceId) async {
    try {
      await remoteDataSource.deleteInvoice(groupId, invoiceId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Invoice>> submitInvoice(String groupId, String invoiceId) async {
    try {
      final result = await remoteDataSource.submitInvoice(groupId, invoiceId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PaymentRequest>> createPaymentRequest(String groupId) async {
    try {
      final result = await remoteDataSource.createPaymentRequest(groupId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PaymentRequest>>> getPaymentRequests(String groupId) async {
    try {
      final result = await remoteDataSource.getPaymentRequests(groupId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, PaymentRequest>> getPaymentRequestById(String groupId, String requestId) async {
    try {
      final result = await remoteDataSource.getPaymentRequestById(groupId, requestId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelPaymentRequest(String groupId, String requestId) async {
    try {
      await remoteDataSource.cancelPaymentRequest(groupId, requestId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Transfer>>> getMyTransfers(String groupId) async {
    try {
      final result = await remoteDataSource.getMyTransfers(groupId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Transfer>> getTransferById(String transferId) async {
    try {
      final result = await remoteDataSource.getTransferById(transferId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> initiatePayment(String transferId, {String? totpToken}) async {
    try {
      final result = await remoteDataSource.initiatePayment(transferId, totpToken: totpToken);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Transfer>> verifyOTPAndPay(String transferId, String otp) async {
    try {
      final result = await remoteDataSource.verifyOTPAndPay(transferId, otp);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resendOTP(String transferId) async {
    try {
      await remoteDataSource.resendOTP(transferId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> cancelTransfer(String transferId) async {
    try {
      await remoteDataSource.cancelTransfer(transferId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, MyBalance>> getMyBalance(String groupId) async {
    try {
      final result = await remoteDataSource.getMyBalance(groupId);
      return Right(result);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
