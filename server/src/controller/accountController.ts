import { Request, Response } from 'express';
import { accountService } from '../service/accountService';
import { vnpayService } from '../service/vnpayService';
import { ResponseUtil } from '../util/responseUtil';
import { CreateTopUpRequest, TopUpResponse, TopUpStatus } from '../type/account';
import { ApiResponse } from '../type/group';
import { User } from '../models/User';

export const accountController = {
    async getBalance(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const user = await User.findById(req.user.userId);
            if (!user) {
                return ResponseUtil.notFound(res, 'User not found');
            }

            ResponseUtil.success(res, {
                balance: Number(user.balance),
                currency: 'VND'
            }, 'Balance retrieved successfully');

        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get balance');
        }
    },

    async initiateTopUp(
        req: Request<{}, {}, { amount: number }>,
        res: Response<ApiResponse<TopUpResponse>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { amount } = req.body;

            if (!amount || amount <= 0) {
                return ResponseUtil.validationError(res, 'Amount must be greater than 0');
            }

            // Get client IP
            const ipAddr = req.headers['x-forwarded-for'] as string || req.socket.remoteAddress || '127.0.0.1';

            // Auto-generate returnUrl from environment or use default
            const baseUrl = process.env.CLIENT_URL || 'http://localhost:3000';
            const returnUrl = `${baseUrl}/topup/return`;

            // Create pending top-up record
            const topUpId = await accountService.createTopUp(req.user.userId, amount);

            // Generate VNPay URL
            const payment = await vnpayService.createTopUpUrl(topUpId, amount, returnUrl, ipAddr);

            ResponseUtil.success(res, {
                id: topUpId,
                accountId: req.user.userId,
                amount,
                status: TopUpStatus.PENDING,
                paymentUrl: payment.paymentUrl,
                createdAt: new Date()
            }, 'Top-up initiated successfully');

        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to initiate top-up');
        }
    },

    async completeTopUp(
        req: Request<{ topUpId: string }, {}, { vnpayTxnRef: string }>,
        res: Response
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { topUpId } = req.params;
            const { vnpayTxnRef } = req.body;

            if (!vnpayTxnRef) {
                return ResponseUtil.validationError(res, 'VNPay transaction reference is required');
            }

            const result = await accountService.completeTopUp(topUpId, vnpayTxnRef);

            ResponseUtil.success(res, result, 'Top-up completed successfully');

        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to complete top-up');
        }
    },

    /**
     * Update FCM token for push notifications
     * PUT /api/accounts/fcm-token
     */
    async updateFcmToken(
        req: Request<{}, {}, { fcmToken: string }>,
        res: Response
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const rawToken = req.body.fcmToken;
            const fcmToken = typeof rawToken === 'string' ? rawToken.trim() : '';

            if (!fcmToken) {
                return ResponseUtil.validationError(res, 'FCM token is required');
            }

            // Keep one device token mapped to a single user.
            await User.updateMany(
                { _id: { $ne: req.user.userId }, fcmToken },
                { $set: { fcmToken: null } }
            );

            await User.findByIdAndUpdate(req.user.userId, { fcmToken });

            ResponseUtil.success(res, null, 'FCM token updated successfully');

        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to update FCM token');
        }
    },

    /**
     * Delete FCM token (logout)
     * DELETE /api/accounts/fcm-token
     */
    async deleteFcmToken(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            await User.findByIdAndUpdate(req.user.userId, { fcmToken: null });

            ResponseUtil.success(res, null, 'FCM token deleted successfully');

        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to delete FCM token');
        }
    }
};
