import { Request, Response } from 'express';
import { settlementService } from '../service/settlementService';
import { vnpayService } from '../service/vnpayService';
import { originalDebtService } from '../service/originalDebtService';
import { ResponseUtil } from '../util/responseUtil';

export const debtController = {
    async getUserDebts(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            const { groupId } = req.params;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            // Use OriginalDebt-based calculation for consistency with global debt summary
            const debts = await originalDebtService.getUserDebtsInGroup(userId, groupId);
            ResponseUtil.success(res, debts, 'Debts retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get debts');
        }
    },

    async payWithBalance(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            const { settlementId } = req.params;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const result = await settlementService.payWithBalance(userId, settlementId);
            ResponseUtil.success(res, result, 'Payment completed successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Payment failed');
        }
    },

    async payWithVNPay(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            const { settlementId } = req.params;
            const { returnUrl } = req.body;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            if (!returnUrl) {
                return ResponseUtil.validationError(res, 'Return URL is required');
            }

            // Get client IP
            const ipAddr = req.headers['x-forwarded-for'] as string ||
                req.socket.remoteAddress ||
                '127.0.0.1';

            const result = await vnpayService.createPaymentUrl(settlementId, returnUrl, ipAddr);
            ResponseUtil.success(res, result, 'Payment URL created successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create payment URL');
        }
    },

    /**
     * Quick pay: Trả nợ trực tiếp (tự động tạo settlement và thanh toán)
     */
    async quickPay(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            const { groupId } = req.params;
            const { toUserId, amount, paymentMethod } = req.body;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            if (!toUserId || !amount) {
                return ResponseUtil.validationError(res, 'Recipient and amount are required');
            }

            const method = paymentMethod === 'VNPAY' ? 'VNPAY' : 'BALANCE';
            const result = await settlementService.quickPayDebt(userId, groupId, toUserId, amount, method);

            if (method === 'VNPAY' && result.status === 'PENDING') {
                // Need to redirect to VNPay
                const returnUrl = req.body.returnUrl || 'http://localhost:3000/payment-return';
                const ipAddr = req.headers['x-forwarded-for'] as string || req.socket.remoteAddress || '127.0.0.1';
                const vnpayResult = await vnpayService.createPaymentUrl(result.settlementId, returnUrl, ipAddr);
                ResponseUtil.success(res, { ...result, paymentUrl: vnpayResult.paymentUrl }, 'Payment initiated successfully');
            } else {
                ResponseUtil.success(res, result, 'Payment completed successfully');
            }
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Quick payment failed');
        }
    },

    /**
     * Lấy các khoản tôi đang nợ (chờ thanh toán)
     */
    async getMyPendingDebts(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            const { groupId } = req.params;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const result = await settlementService.getMyPendingDebts(userId, groupId);
            ResponseUtil.success(res, result, 'Pending debts retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get pending debts');
        }
    },

    /**
     * Lấy các khoản người khác đang nợ tôi
     */
    async getMyPendingCredits(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            const { groupId } = req.params;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const result = await settlementService.getMyPendingCredits(userId, groupId);
            ResponseUtil.success(res, result, 'Pending credits retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get pending credits');
        }
    },

    /**
     * Get global debt summary for user across all groups
     */
    async getAllUserDebts(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const result = await settlementService.getAllUserDebts(userId);
            ResponseUtil.success(res, result, 'Global debt summary retrieved successfully');
        } catch (error) {
            console.error('[ERROR] getAllUserDebts failed:', error);
            ResponseUtil.handleError(res, error, 'Failed to get global debt summary');
        }
    }
};
