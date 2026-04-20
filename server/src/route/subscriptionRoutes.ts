import { Router } from 'express';
import { subscriptionController } from '../controller/subscriptionController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

router.use(authMiddleware);

// ── Collection routes ──────────────────────────────────────────────────────

router.post('/', subscriptionController.createSubscription);
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

// ── Resource routes ────────────────────────────────────────────────────────

router.get('/:id', subscriptionController.getSubscriptionById);
router.get('/:id/members', subscriptionController.getMembers);
router.get('/:id/billing-history', subscriptionController.getBillingHistory);

router.post('/:id/cancel', subscriptionController.cancelSubscription);
router.post('/:id/leave', subscriptionController.leaveSubscription);

// ── Invitation routes ──────────────────────────────────────────────────────

router.post('/:id/invite', subscriptionController.inviteMember);
router.post('/:id/invite/respond', subscriptionController.respondToInvitation);

export default router;
