import { Router } from 'express';
import { authController } from '../controller/authController';
import { twoFactorController } from '../controller/twoFactorController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

router.post('/signup', authController.signUp);

// Verify OTP and activate account
router.post('/verify-otp', authController.verifyOTP);

// Resend OTP
router.post('/resend-otp', authController.resendOTP);

// Login
router.post('/login', authController.loginUser);

// Forgot Password - Send OTP
router.post('/forgot-password', authController.forgotPassword);

// Verify Reset OTP
router.post('/verify-reset-otp', authController.verifyResetOTP);

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
