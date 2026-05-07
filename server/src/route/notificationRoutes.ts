import { Router } from 'express';
import { notificationController } from '../controller/notificationController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

// ── Per-user: 30 writes/minute ─────────────────────────────────────────
const notifWriteLimiter = createRateLimit({
    keyPrefix: 'notif:write',
    windowMs: 60_000,
    maxRequests: 30,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP: 60 writes/minute ───────────────────────────────────────────
const notifWriteIpLimiter = createRateLimit({
    keyPrefix: 'notif:write:ip',
    windowMs: 60_000,
    maxRequests: 60,
    keyGenerator: (req) => req.ip || 'unknown'
});

// All notification routes require authentication
router.use(authMiddleware);

// Get user notifications
router.get('/', notificationController.getUserNotifications);

// Get unread count
router.get('/unread-count', notificationController.getUnreadCount);

// Mark all as read
router.patch('/read-all', notifWriteIpLimiter, notifWriteLimiter, notificationController.markAllAsRead);

// Delete all read notifications
router.delete('/read', notifWriteIpLimiter, notifWriteLimiter, notificationController.deleteAllRead);

// Mark specific notification as read
router.patch('/:notificationId/read', notifWriteIpLimiter, notifWriteLimiter, notificationController.markAsRead);

// Delete specific notification
router.delete('/:notificationId', notifWriteIpLimiter, notifWriteLimiter, notificationController.deleteNotification);

export default router;
