import { Router } from 'express';
import { paymentRequestController } from '../controller/paymentRequestController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Payment Request CRUD
router.post('/:groupId', paymentRequestController.createPaymentRequest);
router.get('/:groupId', paymentRequestController.getPaymentRequests);
router.get('/:groupId/:requestId', paymentRequestController.getPaymentRequestById);

// Payment Request actions
router.post('/:groupId/:requestId/cancel', paymentRequestController.cancelPaymentRequest);

export default router;
