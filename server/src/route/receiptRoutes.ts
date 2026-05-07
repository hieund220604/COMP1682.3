import { Router } from 'express';
import { receiptController } from '../controller/receiptController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

// ── Per-user rate limits ───────────────────────────────────────────────
const createReceiptLimiter = createRateLimit({
    keyPrefix: 'receipt:create',
    windowMs: 60_000,
    maxRequests: 20,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

const mutateReceiptLimiter = createRateLimit({
    keyPrefix: 'receipt:mutate',
    windowMs: 60_000,
    maxRequests: 40,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

const tagLimiter = createRateLimit({
    keyPrefix: 'receipt:tag',
    windowMs: 60_000,
    maxRequests: 30,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP rate limit for receipt write operations ─────────────────────
const receiptWriteIpLimiter = createRateLimit({
    keyPrefix: 'receipt:write:ip',
    windowMs: 60_000,
    maxRequests: 60,
    keyGenerator: (req) => req.ip || 'unknown'
});

// All routes require auth
router.use(authMiddleware);

// Tag CRUD
router.get('/tags', receiptController.listTags);
router.post('/tags', receiptWriteIpLimiter, tagLimiter, receiptController.createTag);
router.put('/tags/:id', receiptWriteIpLimiter, tagLimiter, receiptController.updateTag);
router.delete('/tags/:id', receiptWriteIpLimiter, tagLimiter, receiptController.deleteTag);

// Receipts
router.post('/', receiptWriteIpLimiter, createReceiptLimiter, receiptController.createReceipt);
router.get('/month', receiptController.getMonthSummary);
router.get('/day/:date', receiptController.getDayReceipts);
router.put('/:id', receiptWriteIpLimiter, mutateReceiptLimiter, receiptController.updateReceipt);
router.delete('/:id', receiptWriteIpLimiter, mutateReceiptLimiter, receiptController.deleteReceipt);

export default router;
