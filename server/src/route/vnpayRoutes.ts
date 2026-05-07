import { Router } from 'express';
import { vnpayController } from '../controller/vnpayController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

// ── Per-user: 5 payment initiations/minute ─────────────────────────────
const paymentInitLimiter = createRateLimit({
    keyPrefix: 'vnpay:init',
    windowMs: 60_000,
    maxRequests: 5,
    message: 'Too many payment attempts. Please wait.',
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP: 15 payment initiations/minute ──────────────────────────────
const paymentInitIpLimiter = createRateLimit({
    keyPrefix: 'vnpay:init:ip',
    windowMs: 60_000,
    maxRequests: 15,
    keyGenerator: (req) => req.ip || 'unknown'
});

// Create payment requires authentication
router.post('/', authMiddleware, paymentInitIpLimiter, paymentInitLimiter, vnpayController.createPayment);
router.post('/topup', authMiddleware, paymentInitIpLimiter, paymentInitLimiter, vnpayController.createTopUp);

// VNPay callbacks - no auth required (called by VNPay server)
router.get('/vnpay-return', vnpayController.vnpayReturn);
router.get('/vnpay-ipn', vnpayController.vnpayIPN);

export default router;
