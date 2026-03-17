import { Request, Router } from 'express';
import { transferController } from '../controller/transferController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

const transferOtpKey = (req: Request) => `${req.user?.userId || 'anonymous'}:${req.params?.transferId || 'unknown'}`;

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

// All routes require authentication
router.use(authMiddleware);

// Get my transfers in a group
router.get('/group/:groupId', transferController.getMyTransfers);

// Transfer by ID
router.get('/:transferId', transferController.getTransferById);

// Payment actions
router.post('/:transferId/pay', transferController.initiatePayment);
router.post('/:transferId/verify-otp', transferVerifyOtpRateLimit, transferController.verifyOTPAndPay);
router.post('/:transferId/resend-otp', transferResendOtpRateLimit, transferController.resendOTP);
router.post('/:transferId/cancel', transferController.cancelTransfer);

export default router;
