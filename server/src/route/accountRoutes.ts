import { Router } from 'express';
import { accountController } from '../controller/accountController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Get user balance
router.get('/balance', accountController.getBalance);

// Initiate Top-Up
router.post('/top-up', accountController.initiateTopUp);

// Complete Top-Up
router.post('/top-up/:topUpId/complete', accountController.completeTopUp);

// FCM Token Management
router.put('/fcm-token', accountController.updateFcmToken);
router.delete('/fcm-token', accountController.deleteFcmToken);

export default router;
