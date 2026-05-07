import { Router } from 'express';
import { chatController } from '../controller/chatController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

// ── Per-user: 30 messages/minute ───────────────────────────────────────
const chatLimiter = createRateLimit({
    keyPrefix: 'chat:send',
    windowMs: 60_000,
    maxRequests: 30,
    message: 'Message rate limit reached. Please slow down.',
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP: 60 messages/minute ─────────────────────────────────────────
const chatIpLimiter = createRateLimit({
    keyPrefix: 'chat:send:ip',
    windowMs: 60_000,
    maxRequests: 60,
    keyGenerator: (req) => req.ip || 'unknown'
});

// All routes require authentication
router.use(authMiddleware);

// Chat routes
router.post('/groups/:groupId/messages', chatIpLimiter, chatLimiter, chatController.sendMessage);
router.get('/groups/:groupId/messages', chatController.getMessages);

export default router;
