import { Router } from 'express';
import multer from 'multer';
import { aiController } from '../controller/aiController';
import { authMiddleware } from '../middleware/authMiddleware';

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

router.use(authMiddleware);

router.post('/extract-invoice', aiController.extractInvoice);
router.post('/ocr', upload.single('file'), aiController.extractInvoiceFromImage);
router.post('/debt-reminder', aiController.generateDebtReminder);

export default router;
