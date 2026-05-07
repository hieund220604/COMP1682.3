import { Router } from 'express';
import multer from 'multer';
import { aiController } from '../controller/aiController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024
    },
    fileFilter: (req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Only images are allowed'));
        }
    }
});

// ── Per-user: 10 AI calls/minute ───────────────────────────────────────
const aiLimiter = createRateLimit({
    keyPrefix: 'ai:call',
    windowMs: 60_000,
    maxRequests: 10,
    message: 'AI request limit reached. Please wait before trying again.',
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP: 30 AI calls/minute (prevents multi-account abuse) ──────────
const aiIpLimiter = createRateLimit({
    keyPrefix: 'ai:call:ip',
    windowMs: 60_000,
    maxRequests: 30,
    message: 'Too many AI requests from this network. Please slow down.',
    keyGenerator: (req) => req.ip || 'unknown'
});

router.use(authMiddleware);

router.post('/extract-invoice', aiIpLimiter, aiLimiter, aiController.extractInvoice);
router.post('/ocr', aiIpLimiter, aiLimiter, upload.single('file'), aiController.extractInvoiceFromImage);
router.post('/debt-reminder', aiIpLimiter, aiLimiter, aiController.generateDebtReminder);

export default router;
