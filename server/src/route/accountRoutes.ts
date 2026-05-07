import { Router } from 'express';
import { accountController } from '../controller/accountController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

// ── Per-user: 10 writes/minute ─────────────────────────────────────────
const accountWriteLimiter = createRateLimit({
    keyPrefix: 'account:write',
    windowMs: 60_000,
    maxRequests: 10,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP: 25 writes/minute ───────────────────────────────────────────
const accountWriteIpLimiter = createRateLimit({
    keyPrefix: 'account:write:ip',
    windowMs: 60_000,
    maxRequests: 25,
    keyGenerator: (req) => req.ip || 'unknown'
});

// All routes require authentication
router.use(authMiddleware);

// Get user balance
router.get('/balance', accountController.getBalance);

// Initiate Top-Up
router.post('/top-up', accountWriteIpLimiter, accountWriteLimiter, accountController.initiateTopUp);

// FCM Token Management
router.put('/fcm-token', accountWriteIpLimiter, accountWriteLimiter, accountController.updateFcmToken);
router.delete('/fcm-token', accountWriteIpLimiter, accountWriteLimiter, accountController.deleteFcmToken);

// Push notification preference
router.get('/notification-preferences', accountController.getNotificationPreferences);
router.patch('/notification-preferences', accountWriteIpLimiter, accountWriteLimiter, accountController.updateNotificationPreferences);
router.put('/notification-preferences', accountWriteIpLimiter, accountWriteLimiter, accountController.updateNotificationPreferences);

export default router;
