import { Router } from 'express';
import { billTemplateController } from '../controller/billTemplateController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router({ mergeParams: true }); // access :groupId from parent

// ── Per-user: 15 writes/minute ─────────────────────────────────────────
const billWriteLimiter = createRateLimit({
    keyPrefix: 'bill:write',
    windowMs: 60_000,
    maxRequests: 15,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP: 40 writes/minute ───────────────────────────────────────────
const billWriteIpLimiter = createRateLimit({
    keyPrefix: 'bill:write:ip',
    windowMs: 60_000,
    maxRequests: 40,
    keyGenerator: (req) => req.ip || 'unknown'
});

router.use(authMiddleware);

// ── Template CRUD ──────────────────────────────────────────────────────
router.post('/', billWriteIpLimiter, billWriteLimiter, billTemplateController.createTemplate);
router.get('/', billTemplateController.getTemplates);
router.get('/:templateId', billTemplateController.getTemplateById);
router.put('/:templateId', billWriteIpLimiter, billWriteLimiter, billTemplateController.updateTemplate);
router.delete('/:templateId', billWriteIpLimiter, billWriteLimiter, billTemplateController.archiveTemplate);

// ── Template actions ───────────────────────────────────────────────────
router.patch('/:templateId/pause', billWriteIpLimiter, billWriteLimiter, billTemplateController.pauseTemplate);
router.patch('/:templateId/resume', billWriteIpLimiter, billWriteLimiter, billTemplateController.resumeTemplate);
router.post('/:templateId/generate-now', billWriteIpLimiter, billWriteLimiter, billTemplateController.generateNow);

export default router;
