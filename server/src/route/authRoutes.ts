import { Request, Router } from 'express';
import { authController } from '../controller/authController';
import { twoFactorController } from '../controller/twoFactorController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';
import { loginGuard } from '../middleware/loginGuardMiddleware';

const router = Router();

const otpEmailKey = (req: Request) => `${String(req.body?.email || 'unknown').trim().toLowerCase()}:${req.ip || 'unknown'}`;

const resendOtpRateLimit = createRateLimit({
    keyPrefix: 'otp:resend',
    windowMs: 10 * 60 * 1000,
    maxRequests: 3,
    message: 'Too many OTP resend requests. Please wait a few minutes.',
    keyGenerator: otpEmailKey
});

const verifyOtpRateLimit = createRateLimit({
    keyPrefix: 'otp:verify',
    windowMs: 5 * 60 * 1000,
    maxRequests: 8,
    message: 'Too many OTP verify attempts. Please try again later.',
    keyGenerator: otpEmailKey
});

router.post('/signup', authController.signUp);

// Verify OTP and activate account
router.post('/verify-otp', verifyOtpRateLimit, authController.verifyOTP);

// Resend OTP
router.post('/resend-otp', resendOtpRateLimit, authController.resendOTP);

// Login
router.post('/login', loginGuard, authController.loginUser);

// Forgot Password - Send OTP
router.post('/forgot-password', authController.forgotPassword);

// Verify Reset OTP
router.post('/verify-reset-otp', verifyOtpRateLimit, authController.verifyResetOTP);

// Reset Password with Token (after OTP verified)
router.post('/reset-password-token', authController.resetPasswordWithToken);

// Reset password with token (legacy)
router.post('/reset-password', authController.resetPassword);

// Get current user info
router.get('/me', authMiddleware, authController.getCurrentUser);

// Update user profile
router.patch('/profile', authMiddleware, authController.updateProfile);

// Change Password
router.post('/change-password/initiate', authMiddleware, authController.initiateChangePassword);
router.post('/change-password/confirm', authMiddleware, authController.confirmChangePassword);

// Contact Us
router.post('/contact-us', authMiddleware, authController.contactUs);

// ── Two-Factor Authentication ───────────────────────────────
router.post('/2fa/setup', authMiddleware, twoFactorController.setup);
router.post('/2fa/verify-setup', authMiddleware, twoFactorController.verifySetup);
router.post('/2fa/verify', twoFactorController.verifyLogin);  // No authMiddleware — uses tempToken
router.post('/2fa/disable', authMiddleware, twoFactorController.disable);
router.get('/2fa/status', authMiddleware, twoFactorController.status);

export default router;
