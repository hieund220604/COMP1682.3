import { Router } from 'express';
import { paymentRequestController } from '../controller/paymentRequestController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

// ── Per-user rate limits ───────────────────────────────────────────────
const paymentCreateLimiter = createRateLimit({
    keyPrefix: 'payment:create',
    windowMs: 60_000,
    maxRequests: 5,
    message: 'Payment request limit reached. Please wait.',
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

const paymentWriteLimiter = createRateLimit({
    keyPrefix: 'payment:write',
    windowMs: 60_000,
    maxRequests: 10,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP rate limits ─────────────────────────────────────────────────
const paymentIpLimiter = createRateLimit({
    keyPrefix: 'payment:ip',
    windowMs: 60_000,
    maxRequests: 15,
    keyGenerator: (req) => req.ip || 'unknown'
});

// All routes require authentication
router.use(authMiddleware);

// Payment Request CRUD
router.post('/:groupId', paymentIpLimiter, paymentCreateLimiter, paymentRequestController.createPaymentRequest);
router.get('/:groupId', paymentRequestController.getPaymentRequests);
router.get('/:groupId/:requestId', paymentRequestController.getPaymentRequestById);

// Payment Request actions
router.post('/:groupId/:requestId/cancel', paymentIpLimiter, paymentWriteLimiter, paymentRequestController.cancelPaymentRequest);

export default router;
