import { Request, Router } from 'express';
import { withdrawalController } from '../controller/withdrawalController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

const withdrawalOtpKey = (req: Request) => `${req.user?.userId || 'anonymous'}:${req.params?.withdrawalId || 'unknown'}`;

const withdrawalResendOtpRateLimit = createRateLimit({
    keyPrefix: 'withdrawal:otp:resend',
    windowMs: 10 * 60 * 1000,
    maxRequests: 3,
    message: 'Too many withdrawal OTP resend requests. Please wait a few minutes.',
    keyGenerator: withdrawalOtpKey
});

const withdrawalVerifyOtpRateLimit = createRateLimit({
    keyPrefix: 'withdrawal:otp:verify',
    windowMs: 5 * 60 * 1000,
    maxRequests: 8,
    message: 'Too many withdrawal OTP verify attempts. Please try again later.',
    keyGenerator: withdrawalOtpKey
});

// All routes require authentication
router.use(authMiddleware);

// Withdrawal routes
router.post('/', withdrawalController.initiateWithdrawal);
router.post('/:withdrawalId/resend-otp', withdrawalResendOtpRateLimit, withdrawalController.resendOTP);
router.post('/:withdrawalId/verify-otp', withdrawalVerifyOtpRateLimit, withdrawalController.verifyOTP);
router.get('/:withdrawalId', withdrawalController.getWithdrawalStatus);
router.get('/', withdrawalController.getUserWithdrawals);

export default router;
