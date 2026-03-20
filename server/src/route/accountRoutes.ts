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

// FCM Token Management
router.put('/fcm-token', accountController.updateFcmToken);
router.delete('/fcm-token', accountController.deleteFcmToken);

// Push notification preference
router.get('/notification-preferences', accountController.getNotificationPreferences);
router.patch('/notification-preferences', accountController.updateNotificationPreferences);
router.put('/notification-preferences', accountController.updateNotificationPreferences);

export default router;
