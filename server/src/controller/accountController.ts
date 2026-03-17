import { Request, Response } from 'express';
import { accountService } from '../service/accountService';
import { vnpayService } from '../service/vnpayService';
import { ResponseUtil } from '../util/responseUtil';
import { TopUpResponse, TopUpStatus } from '../type/account';
import { ApiResponse } from '../type/group';
import { User } from '../models/User';

const normalizeIpAddress = (rawIp?: string): string => {
    if (!rawIp) return '127.0.0.1';

    const firstIp = rawIp.split(',')[0]?.trim() || rawIp.trim();
    if (firstIp.startsWith('::ffff:')) {
        return firstIp.replace('::ffff:', '');
    }

    return firstIp;
};

const resolveVNPayReturnUrl = () => {
    const configuredUrl = process.env.VNPAY_RETURN_URL?.trim();

    if (!configuredUrl) {
        throw new Error('VNPAY_RETURN_URL is required. This must be the approved URL in your VNPay merchant configuration.');
    }

    let parsed: URL;
    try {
        parsed = new URL(configuredUrl);
    } catch (_error) {
        throw new Error('VNPAY_RETURN_URL is invalid. Please provide a valid absolute URL.');
    }

    const isLocalHost = parsed.hostname === 'localhost' || parsed.hostname === '127.0.0.1';
    if (isLocalHost && process.env.VNPAY_ALLOW_LOCAL_RETURN_URL !== 'true') {
        throw new Error('VNPAY_RETURN_URL is localhost, which is typically not approved by VNPay. Use a public HTTPS domain (or tunnel) and register it with VNPay.');
    }

    if (parsed.hostname.includes('vnpayment.vn')) {
        throw new Error('VNPAY_RETURN_URL must be your merchant callback URL, not a VNPay URL. Example: https://your-domain/api/payments/vnpay-return');
    }

    return configuredUrl;
};

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

            const ipAddr = normalizeIpAddress(req.headers['x-forwarded-for'] as string || req.socket.remoteAddress || '127.0.0.1');
            const returnUrl = resolveVNPayReturnUrl();

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
            ResponseUtil.error(
                res,
                'Deprecated endpoint. Top-up completion is now handled by VNPay IPN only.',
                410
            );

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
