import { Router } from 'express';
import { receiptController } from '../controller/receiptController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

// Rate limits
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

// All routes require auth
router.use(authMiddleware);

// Tag CRUD
router.get('/tags', receiptController.listTags);
router.post('/tags', tagLimiter, receiptController.createTag);
router.put('/tags/:id', tagLimiter, receiptController.updateTag);
router.delete('/tags/:id', tagLimiter, receiptController.deleteTag);

// Receipts
router.post('/', createReceiptLimiter, receiptController.createReceipt);
router.get('/month', receiptController.getMonthSummary);
router.get('/day/:date', receiptController.getDayReceipts);
router.put('/:id', mutateReceiptLimiter, receiptController.updateReceipt);
router.delete('/:id', mutateReceiptLimiter, receiptController.deleteReceipt);

export default router;
