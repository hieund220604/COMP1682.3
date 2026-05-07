import { Router } from 'express';
import { subscriptionController } from '../controller/subscriptionController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

// ── Per-user: 15 writes/minute ─────────────────────────────────────────
const subWriteLimiter = createRateLimit({
    keyPrefix: 'sub:write',
    windowMs: 60_000,
    maxRequests: 15,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP: 40 writes/minute ───────────────────────────────────────────
const subWriteIpLimiter = createRateLimit({
    keyPrefix: 'sub:write:ip',
    windowMs: 60_000,
    maxRequests: 40,
    keyGenerator: (req) => req.ip || 'unknown'
});

router.use(authMiddleware);

// ── Collection routes ──────────────────────────────────────────────────

router.post('/', subWriteIpLimiter, subWriteLimiter, subscriptionController.createSubscription);
router.get('/', subscriptionController.getSubscriptions);

// Cron/admin: process per-member renewals
const cronGuard = (req: any, res: any, next: any) => {
    const secret = process.env.CRON_SECRET;
    if (secret && req.headers['x-cron-secret'] !== secret) {
        return res.status(403).json({ success: false, message: 'Forbidden: invalid cron secret' });
    }
    next();
};
router.post('/process-charges', cronGuard, subscriptionController.processCharges);

// ── Resource routes ────────────────────────────────────────────────────

router.get('/:id', subscriptionController.getSubscriptionById);
router.get('/:id/members', subscriptionController.getMembers);
router.get('/:id/billing-history', subscriptionController.getBillingHistory);

router.post('/:id/cancel', subWriteIpLimiter, subWriteLimiter, subscriptionController.cancelSubscription);
router.post('/:id/leave', subWriteIpLimiter, subWriteLimiter, subscriptionController.leaveSubscription);

// ── Invitation routes ──────────────────────────────────────────────────

router.post('/:id/invite', subWriteIpLimiter, subWriteLimiter, subscriptionController.inviteMember);
router.post('/:id/invite/respond', subWriteIpLimiter, subWriteLimiter, subscriptionController.respondToInvitation);

export default router;
