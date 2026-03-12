import { Router } from 'express';
import { vnpayController } from '../controller/vnpayController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// Create payment requires authentication
router.post('/', authMiddleware, vnpayController.createPayment);
router.post('/topup', authMiddleware, vnpayController.createTopUp);

// VNPay callbacks - no auth required (called by VNPay)
router.get('/vnpay-return', vnpayController.vnpayReturn);
router.get('/vnpay-ipn', vnpayController.vnpayIPN);

export default router;
