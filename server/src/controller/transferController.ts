import { Request, Response } from 'express';
import { transferService } from '../service/transferService';
import { paymentRequestService } from '../service/paymentRequestService';
import { twoFactorService } from '../service/twoFactorService';
import { ResponseUtil } from '../util/responseUtil';

export const transferController = {
    /**
     * Get my transfers in a group
     * GET /api/groups/:groupId/transfers
     */
    async getMyTransfers(req: Request, res: Response): Promise<void> {
        try {
            const { groupId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const transfers = await transferService.getMyTransfers(userId, groupId);
            ResponseUtil.success(res, transfers, 'Transfers retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get transfers');
        }
    },

    /**
     * Get transfer by ID
     * GET /api/transfers/:transferId
     */
    async getTransferById(req: Request, res: Response): Promise<void> {
        try {
            const { transferId } = req.params;

            const transfer = await transferService.getTransferById(transferId);
            if (!transfer) {
                return ResponseUtil.notFound(res, 'Transfer not found');
            }

            ResponseUtil.success(res, transfer, 'Transfer retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get transfer');
        }
    },

    /**
     * Initiate payment - send OTP
     * POST /api/transfers/:transferId/pay
     */
    async initiatePayment(req: Request, res: Response): Promise<void> {
        try {
            const { transferId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            // 2FA guard
            const { totpToken } = req.body;
            await twoFactorService.verify2FAIfEnabled(userId, totpToken);

            const result = await transferService.initiatePayment(userId, transferId);
            ResponseUtil.success(res, result, 'OTP sent successfully. Please check your email.');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to initiate payment');
        }
    },

    /**
     * Verify OTP and complete payment
     * POST /api/transfers/:transferId/verify-otp
     */
    async verifyOTPAndPay(req: Request, res: Response): Promise<void> {
        try {
            const { transferId } = req.params;
            const { otp } = req.body;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            if (!otp) {
                return ResponseUtil.validationError(res, 'OTP is required');
            }

            const result = await transferService.verifyOTPAndPay(userId, transferId, otp);
            ResponseUtil.success(res, result, 'Payment completed successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to verify OTP');
        }
    },

    /**
     * Resend OTP
     * POST /api/transfers/:transferId/resend-otp
     */
    async resendOTP(req: Request, res: Response): Promise<void> {
        try {
            const { transferId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const result = await transferService.resendOTP(userId, transferId);
            ResponseUtil.success(res, result, 'OTP resent successfully. Please check your email.');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to resend OTP');
        }
    },

    /**
     * Cancel a single pending transfer
     * POST /api/transfers/:transferId/cancel
     */
    async cancelTransfer(req: Request, res: Response): Promise<void> {
        try {
            const { transferId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const result = await paymentRequestService.cancelSingleTransfer(userId, transferId);

            if (result.fullCancelTriggered) {
                ResponseUtil.success(res, {
                    fullCancelTriggered: true,
                    refundedTransfers: result.refundedTransfers,
                    cancelledTransfers: result.cancelledTransfers
                }, 'Payment request cancelled with refunds due to existing completed transfers');
            } else {
                ResponseUtil.success(res, { fullCancelTriggered: false }, 'Transfer cancelled successfully');
            }
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to cancel transfer');
        }
    }
};
