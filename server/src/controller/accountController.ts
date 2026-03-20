import { Request, Response } from 'express';
import { accountService } from '../service/accountService';
import { vnpayService } from '../service/vnpayService';
import { ResponseUtil } from '../util/responseUtil';
import { TopUpResponse, TopUpStatus } from '../type/account';
import { ApiResponse } from '../type/group';
import { User } from '../models/User';
import { validateVNPayCallbackUrl } from '../util/vnpayUrlValidation';

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

    return validateVNPayCallbackUrl(configuredUrl, 'VNPAY_RETURN_URL');
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
    },

    /**
     * Get push notification preference
     * GET /api/accounts/notification-preferences
     */
    async getNotificationPreferences(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const user = await User.findById(req.user.userId).select('_id pushNotificationsEnabled');
            if (!user) {
                return ResponseUtil.notFound(res, 'User not found');
            }

            ResponseUtil.success(res, {
                pushNotificationsEnabled: user.pushNotificationsEnabled !== false
            }, 'Notification preferences retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get notification preferences');
        }
    },

    /**
     * Update push notification preference
     * PATCH /api/accounts/notification-preferences
     */
    async updateNotificationPreferences(
        req: Request<{}, {}, { pushNotificationsEnabled?: boolean; enabled?: boolean }>,
        res: Response
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const rawPreference = typeof req.body.pushNotificationsEnabled === 'boolean'
                ? req.body.pushNotificationsEnabled
                : req.body.enabled;

            if (typeof rawPreference !== 'boolean') {
                return ResponseUtil.validationError(res, 'pushNotificationsEnabled must be a boolean');
            }

            const user = await User.findByIdAndUpdate(
                req.user.userId,
                { pushNotificationsEnabled: rawPreference },
                { new: true }
            ).select('_id pushNotificationsEnabled');

            if (!user) {
                return ResponseUtil.notFound(res, 'User not found');
            }

            ResponseUtil.success(res, {
                pushNotificationsEnabled: user.pushNotificationsEnabled !== false
            }, 'Notification preferences updated successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to update notification preferences');
        }
    }
};
