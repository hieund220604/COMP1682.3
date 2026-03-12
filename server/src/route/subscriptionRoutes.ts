import { Router } from 'express';
import { subscriptionController } from '../controller/subscriptionController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// ── Collection routes ──────────────────────────────────────────────────────

// Create subscription (OWNER/ADMIN)
router.post('/', subscriptionController.createSubscription);

// Get all subscriptions for user
router.get('/', subscriptionController.getSubscriptions);

// Process recurring charges (protected by CRON_SECRET in production)
const cronGuard = (req: any, res: any, next: any) => {
    const secret = process.env.CRON_SECRET;
    if (secret && req.headers['x-cron-secret'] !== secret) {
        return res.status(403).json({ success: false, message: 'Forbidden: invalid cron secret' });
    }
    next();
};
router.post('/process-charges', cronGuard, subscriptionController.processCharges);


// ── Resource routes ────────────────────────────────────────────────────────

// Get subscription by ID
router.get('/:id', subscriptionController.getSubscriptionById);

// Get billing history for subscription
router.get('/:id/billing-history', subscriptionController.getBillingHistory);

// Cancel subscription (OWNER/ADMIN)
router.post('/:id/cancel', subscriptionController.cancelSubscription);

// Member self-withdrawal from subscription (any member)
router.post('/:id/leave', subscriptionController.leaveSubscription);

// Pause subscription (OWNER/ADMIN)
router.post('/:id/pause', subscriptionController.pauseSubscription);

// Resume subscription (OWNER/ADMIN)
router.post('/:id/resume', subscriptionController.resumeSubscription);

// Update subscription (OWNER/ADMIN)
router.patch('/:id', subscriptionController.updateSubscription);

export default router;
