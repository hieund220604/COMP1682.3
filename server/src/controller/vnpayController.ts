import { Request, Response } from 'express';
import { vnpayService } from '../service/vnpayService';
import { ResponseUtil } from '../util/responseUtil';
import { CreatePaymentRequest, PaymentResponse } from '../type/vnpay';
import { ApiResponse } from '../type/group';

export const vnpayController = {
    async createPayment(
        req: Request<{}, {}, { transferId: string }>,
        res: Response<ApiResponse<PaymentResponse>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { transferId } = req.body;

            if (!transferId) {
                return ResponseUtil.validationError(res, 'Transfer ID is required');
            }

            // Get client IP
            const ipAddr = req.headers['x-forwarded-for'] as string || req.socket.remoteAddress || '127.0.0.1';

            // Get return URL from env
            const returnUrl = process.env.VNPAY_RETURN_URL || 'http://localhost:8080/api/payments/vnpay-return';

            const payment = await vnpayService.createPaymentUrl(transferId, returnUrl, ipAddr);
            ResponseUtil.success(res, payment, 'Payment URL created successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create payment');
        }
    },

    async createTopUp(
        req: Request<{}, {}, { amount: number }>,
        res: Response<ApiResponse<PaymentResponse>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { amount } = req.body;

            if (!amount) {
                return ResponseUtil.validationError(res, 'Amount is required');
            }

            if (amount <= 0) {
                return ResponseUtil.validationError(res, 'Amount must be greater than 0');
            }

            // Get client IP
            const ipAddr = req.headers['x-forwarded-for'] as string || req.socket.remoteAddress || '127.0.0.1';

            // Get return URL from env
            const returnUrl = process.env.VNPAY_RETURN_URL || 'http://localhost:8080/api/payments/vnpay-return';

            // Create TopUp record with current user's ID
            const topUpId = await require('../service/accountService').accountService.createTopUp(req.user.userId, amount);

            // Generate payment URL
            const payment = await vnpayService.createTopUpUrl(topUpId, amount, returnUrl, ipAddr);
            ResponseUtil.success(res, payment, 'Top-up payment URL created successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create top-up payment');
        }
    },

    async vnpayReturn(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            const query = req.query as Record<string, string>;
            const result = await vnpayService.verifyReturnUrl(query);

            if (result.isValid) {
                ResponseUtil.success(res, { transferId: result.transferId }, result.message);
            } else {
                ResponseUtil.error(res, result.message, 400);
            }
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Payment verification failed');
        }
    },

    async vnpayIPN(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            const query = req.query as Record<string, string>;
            const result = await vnpayService.handleIPN(query);

            // VNPay expects specific response format
            res.status(200).json(result);
        } catch (error) {
            res.status(200).json({
                RspCode: '99',
                Message: 'Unknown error'
            });
        }
    }
};
