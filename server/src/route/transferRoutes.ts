import { Request, Router } from 'express';
import { transferController } from '../controller/transferController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

const transferOtpKey = (req: Request) => `${req.user?.userId || 'anonymous'}:${req.params?.transferId || 'unknown'}`;

// ── Per-user OTP rate limits ───────────────────────────────────────────
const transferResendOtpRateLimit = createRateLimit({
    keyPrefix: 'transfer:otp:resend',
    windowMs: 10 * 60 * 1000,
    maxRequests: 3,
    message: 'Too many transfer OTP resend requests. Please wait a few minutes.',
    keyGenerator: transferOtpKey
});

const transferVerifyOtpRateLimit = createRateLimit({
    keyPrefix: 'transfer:otp:verify',
    windowMs: 5 * 60 * 1000,
    maxRequests: 8,
    message: 'Too many transfer OTP verify attempts. Please try again later.',
    keyGenerator: transferOtpKey
});

// ── Per-IP rate limit for transfer write operations ────────────────────
const transferWriteIpLimiter = createRateLimit({
    keyPrefix: 'transfer:write:ip',
    windowMs: 60_000,
    maxRequests: 30,
    keyGenerator: (req) => req.ip || 'unknown'
});

// All routes require authentication
router.use(authMiddleware);

// Get my transfers in a group
router.get('/group/:groupId', transferController.getMyTransfers);

// Transfer by ID
router.get('/:transferId', transferController.getTransferById);

// Payment actions
router.post('/:transferId/pay', transferWriteIpLimiter, transferController.initiatePayment);
router.post('/:transferId/verify-otp', transferWriteIpLimiter, transferVerifyOtpRateLimit, transferController.verifyOTPAndPay);
router.post('/:transferId/resend-otp', transferWriteIpLimiter, transferResendOtpRateLimit, transferController.resendOTP);
router.post('/:transferId/cancel', transferWriteIpLimiter, transferController.cancelTransfer);

export default router;
