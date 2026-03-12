import { Router } from 'express';
import { withdrawalController } from '../controller/withdrawalController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Withdrawal routes
router.post('/', withdrawalController.initiateWithdrawal);
router.post('/:withdrawalId/resend-otp', withdrawalController.resendOTP);
router.post('/:withdrawalId/verify-otp', withdrawalController.verifyOTP);
router.get('/:withdrawalId', withdrawalController.getWithdrawalStatus);
router.get('/', withdrawalController.getUserWithdrawals);

export default router;
