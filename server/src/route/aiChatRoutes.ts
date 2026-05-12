import { Router } from 'express';
import { aiChatController } from '../controller/aiChatController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

// Rate limiting for AI Chat to prevent abuse
const aiChatLimiter = createRateLimit({
    keyPrefix: 'ai-chat:send',
    windowMs: 60_000,
    maxRequests: 15, // 15 questions per minute max
    message: 'Too many chat requests. Please wait a moment.',
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

router.use(authMiddleware);

router.post('/message', aiChatLimiter, aiChatController.sendMessage);
router.get('/sessions', aiChatController.getSessions);
router.get('/sessions/:id', aiChatController.getSessionHistory);

export default router;
