import express from 'express';
import multer from 'multer';
import { uploadFile } from '../controller/uploadController';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = express.Router();

// Use memory storage — file stays in RAM buffer, uploaded directly to Cloudinary
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024 // 5MB limit
    },
    fileFilter: (req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Only images are allowed'));
        }
    }
});

// ── Per-user: 15 uploads/minute ────────────────────────────────────────
const uploadLimiter = createRateLimit({
    keyPrefix: 'upload:file',
    windowMs: 60_000,
    maxRequests: 15,
    message: 'Upload limit reached. Please wait a moment.',
    keyGenerator: (req) => (req as any).user?.userId || req.ip || 'anon'
});

// ── Per-IP: 40 uploads/minute ──────────────────────────────────────────
const uploadIpLimiter = createRateLimit({
    keyPrefix: 'upload:file:ip',
    windowMs: 60_000,
    maxRequests: 40,
    message: 'Too many uploads from this network.',
    keyGenerator: (req) => req.ip || 'unknown'
});

// Route
router.post('/', uploadIpLimiter, uploadLimiter, upload.single('file'), uploadFile);

export default router;
