import { Router } from 'express';
import { aiController } from '../controller/aiController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

router.use(authMiddleware);

router.post('/extract-invoice', aiController.extractInvoice);

export default router;
