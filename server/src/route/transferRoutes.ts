import { Router } from 'express';
import { transferController } from '../controller/transferController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Get my transfers in a group
router.get('/group/:groupId', transferController.getMyTransfers);

// Transfer by ID
router.get('/:transferId', transferController.getTransferById);

// Payment actions
router.post('/:transferId/pay', transferController.initiatePayment);
router.post('/:transferId/verify-otp', transferController.verifyOTPAndPay);
router.post('/:transferId/resend-otp', transferController.resendOTP);
router.post('/:transferId/cancel', transferController.cancelTransfer);

export default router;
