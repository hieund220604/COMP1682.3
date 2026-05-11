import { Router } from 'express';
import { invoiceController } from '../controller/invoiceController';
import { billTemplateController } from '../controller/billTemplateController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router({ mergeParams: true }); // mergeParams to access :groupId from parent

// ── Per-user: 20 writes/minute ─────────────────────────────────────────
const invoiceWriteLimiter = createRateLimit({
    keyPrefix: 'invoice:write',
    windowMs: 60_000,
    maxRequests: 20,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP: 50 writes/minute ───────────────────────────────────────────
const invoiceWriteIpLimiter = createRateLimit({
    keyPrefix: 'invoice:write:ip',
    windowMs: 60_000,
    maxRequests: 50,
    keyGenerator: (req) => req.ip || 'unknown'
});

// All routes require authentication
router.use(authMiddleware);

// User balance - MUST be before :invoiceId routes
router.get('/:groupId/my-balance', invoiceController.getMyBalance);

// Invoice CRUD
router.post('/:groupId', invoiceWriteIpLimiter, invoiceWriteLimiter, invoiceController.createInvoice);
router.get('/:groupId', invoiceController.getInvoices);
router.get('/:groupId/search', invoiceController.searchInvoices);
router.get('/:groupId/:invoiceId', invoiceController.getInvoiceById);
router.put('/:groupId/:invoiceId', invoiceWriteIpLimiter, invoiceWriteLimiter, invoiceController.updateInvoice);
router.delete('/:groupId/:invoiceId', invoiceWriteIpLimiter, invoiceWriteLimiter, invoiceController.deleteInvoice);

// Invoice actions
router.post('/:groupId/:invoiceId/submit', invoiceWriteIpLimiter, invoiceWriteLimiter, invoiceController.submitInvoice);
router.post('/:groupId/:invoiceId/adjust', invoiceWriteIpLimiter, invoiceWriteLimiter, invoiceController.createAdjustmentInvoice);
router.post('/:groupId/:invoiceId/confirm', invoiceWriteIpLimiter, invoiceWriteLimiter, billTemplateController.confirmDraft);

export default router;
