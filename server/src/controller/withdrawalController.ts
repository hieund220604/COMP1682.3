import { Request, Response } from 'express';
import { withdrawalService } from '../service/withdrawalService';
import { twoFactorService } from '../service/twoFactorService';
import { ResponseUtil } from '../util/responseUtil';
import { CreateWithdrawalRequest, VerifyOtpRequest, WithdrawalResponse, WithdrawalSuccessResponse } from '../type/withdrawal';
import { ApiResponse } from '../type/group';

export const withdrawalController = {
    async initiateWithdrawal(
        req: Request<{}, {}, CreateWithdrawalRequest>,
        res: Response<ApiResponse<WithdrawalResponse>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { amount, accountNumber, bankName, accountName, totpToken } = req.body;

            if (!amount || !accountNumber || !bankName || !accountName) {
                return ResponseUtil.validationError(res, 'All fields are required: amount, accountNumber, bankName, accountName');
            }

            // 2FA guard
            await twoFactorService.verify2FAIfEnabled(req.user.userId, totpToken);

            const withdrawal = await withdrawalService.initiateWithdrawal(req.user.userId, req.body);
            ResponseUtil.success(res, withdrawal, 'Withdrawal initiated successfully. Please check your email for OTP.', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to initiate withdrawal');
        }
    },

    async resendOTP(
        req: Request<{ withdrawalId: string }, {}, {}>,
        res: Response<ApiResponse<WithdrawalSuccessResponse>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { withdrawalId } = req.params;

            if (!withdrawalId) {
                return ResponseUtil.validationError(res, 'Withdrawal ID is required');
            }

            // Verify withdrawal belongs to user
            const withdrawal = await withdrawalService.getWithdrawalStatus(withdrawalId, req.user.userId);

            const result = await withdrawalService.resendOTP(withdrawalId, req.user.email);
            ResponseUtil.success(res, result, 'OTP resent successfully. Please check your email.');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to resend OTP');
        }
    },

    async verifyOTP(
        req: Request<{ withdrawalId: string }, {}, VerifyOtpRequest>,
        res: Response<ApiResponse<WithdrawalSuccessResponse>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { withdrawalId } = req.params;
            const { otp } = req.body;

            if (!otp) {
                return ResponseUtil.validationError(res, 'OTP is required');
            }

            // Verify withdrawal belongs to user
            await withdrawalService.getWithdrawalStatus(withdrawalId, req.user.userId);

            const result = await withdrawalService.verifyOTP(withdrawalId, otp);
            ResponseUtil.success(res, result, 'Withdrawal completed successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to verify OTP');
        }
    },


    async getWithdrawalStatus(
        req: Request<{ withdrawalId: string }, {}, {}>,
        res: Response<ApiResponse<WithdrawalResponse>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { withdrawalId } = req.params;

            const withdrawal = await withdrawalService.getWithdrawalStatus(withdrawalId, req.user.userId);
            ResponseUtil.success(res, withdrawal, 'Withdrawal status retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get withdrawal status');
        }
    },

    async getUserWithdrawals(
        req: Request,
        res: Response<ApiResponse<WithdrawalResponse[]>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const withdrawals = await withdrawalService.getUserWithdrawals(req.user.userId);
            ResponseUtil.success(res, withdrawals, 'Withdrawals retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get withdrawals');
        }
    }
};
