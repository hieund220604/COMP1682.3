import { Request, Router } from 'express';
import { authController } from '../controller/authController';
import { twoFactorController } from '../controller/twoFactorController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';
import { loginGuard } from '../middleware/loginGuardMiddleware';

const router = Router();

const otpEmailKey = (req: Request) => `${String(req.body?.email || 'unknown').trim().toLowerCase()}:${req.ip || 'unknown'}`;

// ── Existing rate limits ───────────────────────────────────────────────
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

// ── Per-user rate limits ───────────────────────────────────────────────
const signupLimiter = createRateLimit({
    keyPrefix: 'auth:signup',
    windowMs: 60 * 60 * 1000,
    maxRequests: 5,
    message: 'Too many signup attempts. Please try again in 1 hour.',
    keyGenerator: (req) => req.ip || 'unknown'
});

const forgotPasswordLimiter = createRateLimit({
    keyPrefix: 'auth:forgot',
    windowMs: 10 * 60 * 1000,
    maxRequests: 3,
    message: 'Too many password reset requests. Please wait a few minutes.',
    keyGenerator: (req) => `${String(req.body?.email || 'unknown').trim().toLowerCase()}:${req.ip || 'unknown'}`
});

const authWriteLimiter = createRateLimit({
    keyPrefix: 'auth:write',
    windowMs: 60_000,
    maxRequests: 15,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

const twoFactorLimiter = createRateLimit({
    keyPrefix: 'auth:2fa',
    windowMs: 5 * 60 * 1000,
    maxRequests: 10,
    message: 'Too many 2FA attempts. Please try again later.',
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP rate limits (dual-key: prevents multi-account abuse) ────────
const authWriteIpLimiter = createRateLimit({
    keyPrefix: 'auth:write:ip',
    windowMs: 60_000,
    maxRequests: 30,
    keyGenerator: (req) => req.ip || 'unknown'
});

const twoFactorIpLimiter = createRateLimit({
    keyPrefix: 'auth:2fa:ip',
    windowMs: 5 * 60 * 1000,
    maxRequests: 25,
    keyGenerator: (req) => req.ip || 'unknown'
});

// ── Public routes ──────────────────────────────────────────────────────
router.post('/signup', signupLimiter, authController.signUp);
router.post('/verify-otp', verifyOtpRateLimit, authController.verifyOTP);
router.post('/resend-otp', resendOtpRateLimit, authController.resendOTP);
router.post('/login', loginGuard, authController.loginUser);
router.post('/google-login', authWriteIpLimiter, authWriteLimiter, authController.loginWithGoogle);
router.post('/forgot-password', forgotPasswordLimiter, authController.forgotPassword);
router.post('/verify-reset-otp', verifyOtpRateLimit, authController.verifyResetOTP);
router.post('/reset-password-token', authWriteIpLimiter, authWriteLimiter, authController.resetPasswordWithToken);
router.post('/reset-password', authWriteIpLimiter, authWriteLimiter, authController.resetPassword);

// ── Authenticated routes ───────────────────────────────────────────────
router.get('/me', authMiddleware, authController.getCurrentUser);
router.patch('/profile', authMiddleware, authWriteIpLimiter, authWriteLimiter, authController.updateProfile);
router.post('/change-password/initiate', authMiddleware, authWriteIpLimiter, authWriteLimiter, authController.initiateChangePassword);
router.post('/change-password/confirm', authMiddleware, authWriteIpLimiter, authWriteLimiter, authController.confirmChangePassword);
router.post('/contact-us', authMiddleware, authWriteIpLimiter, authWriteLimiter, authController.contactUs);

// ── Two-Factor Authentication ──────────────────────────────────────────
router.post('/2fa/setup', authMiddleware, twoFactorIpLimiter, twoFactorLimiter, twoFactorController.setup);
router.post('/2fa/verify-setup', authMiddleware, twoFactorIpLimiter, twoFactorLimiter, twoFactorController.verifySetup);
router.post('/2fa/verify', twoFactorIpLimiter, twoFactorLimiter, twoFactorController.verifyLogin);
router.post('/2fa/disable', authMiddleware, twoFactorIpLimiter, twoFactorLimiter, twoFactorController.disable);
router.get('/2fa/status', authMiddleware, twoFactorController.status);

// ── Token management ───────────────────────────────────────────────────
router.post('/refresh-token', authWriteIpLimiter, authWriteLimiter, authController.refreshToken);
router.post('/logout', authController.logout);

export default router;
