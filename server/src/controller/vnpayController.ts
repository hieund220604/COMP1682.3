import { Request, Response } from 'express';
import { vnpayService } from '../service/vnpayService';
import { accountService } from '../service/accountService';
import { ResponseUtil } from '../util/responseUtil';
import { PaymentResponse } from '../type/vnpay';
import { ApiResponse } from '../type/group';

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

const escapeHtml = (value: string): string => {
        return value
                .replace(/&/g, '&amp;')
                .replace(/</g, '&lt;')
                .replace(/>/g, '&gt;')
                .replace(/"/g, '&quot;')
                .replace(/'/g, '&#39;');
};

const buildReturnHtml = (params: {
        ok: boolean;
        title: string;
        message: string;
        transferId?: string;
        deepLinkUrl?: string;
}): string => {
        const title = escapeHtml(params.title);
        const message = escapeHtml(params.message);
        const transferId = params.transferId ? escapeHtml(params.transferId) : null;
        const deepLinkUrl = params.deepLinkUrl ? escapeHtml(params.deepLinkUrl) : null;
        const color = params.ok ? '#0f766e' : '#b91c1c';

        return `<!doctype html>
<html lang="en">
    <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>VNPay Result</title>
    </head>
    <body style="font-family: Arial, sans-serif; background:#f8fafc; margin:0; padding:24px;">
        <div style="max-width:480px; margin:40px auto; background:#fff; border-radius:12px; padding:24px; box-shadow:0 4px 16px rgba(0,0,0,.08);">
            <h2 style="margin:0 0 12px; color:${color};">${title}</h2>
            <p style="margin:0 0 12px; color:#334155;">${message}</p>
            ${transferId ? `<p style="margin:0 0 18px; color:#475569;">Reference: <strong>${transferId}</strong></p>` : ''}
            ${deepLinkUrl ? `<a href="${deepLinkUrl}" style="display:inline-block; background:#2563eb; color:#fff; text-decoration:none; padding:10px 14px; border-radius:8px;">Open app</a>` : ''}
            <p style="margin:14px 0 0; color:#64748b; font-size:13px;">You can return to the app manually if it does not open automatically.</p>
        </div>
        ${deepLinkUrl ? `<script>setTimeout(function(){ window.location.href='${deepLinkUrl}'; }, 400);</script>` : ''}
    </body>
</html>`;
};

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

            // VNPay expects clean IP format and a stable callback URL.
            const ipAddr = normalizeIpAddress(req.headers['x-forwarded-for'] as string || req.socket.remoteAddress || '127.0.0.1');
            const returnUrl = resolveVNPayReturnUrl();

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

            // VNPay expects clean IP format and a stable callback URL.
            const ipAddr = normalizeIpAddress(req.headers['x-forwarded-for'] as string || req.socket.remoteAddress || '127.0.0.1');
            const returnUrl = resolveVNPayReturnUrl();

            // Create TopUp record with current user's ID
            const topUpId = await accountService.createTopUp(req.user.userId, amount);

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

            const wantsJson = req.query.format === 'json' || req.headers.accept?.includes('application/json');

            const appDeepLinkBase = process.env.VNPAY_APP_DEEP_LINK?.trim();
            const deepLinkUrl = appDeepLinkBase
                ? `${appDeepLinkBase}${appDeepLinkBase.includes('?') ? '&' : '?'}status=${result.isValid ? 'success' : 'failed'}${result.transferId ? `&transferId=${encodeURIComponent(result.transferId)}` : ''}`
                : undefined;

            if (wantsJson) {
                if (result.isValid) {
                    return ResponseUtil.success(res, { transferId: result.transferId }, result.message);
                }
                return ResponseUtil.error(res, result.message, 400);
            }

            const html = buildReturnHtml({
                ok: result.isValid,
                title: result.isValid ? 'Payment verification successful' : 'Payment verification failed',
                message: result.message,
                transferId: result.transferId,
                deepLinkUrl,
            });

            res.status(result.isValid ? 200 : 400).setHeader('Content-Type', 'text/html; charset=utf-8').send(html);
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
