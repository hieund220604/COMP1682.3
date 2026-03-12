import { Router } from 'express';
import { notificationController } from '../controller/notificationController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All notification routes require authentication
router.use(authMiddleware);

// Get user notifications
router.get('/', notificationController.getUserNotifications);

// Get unread count
router.get('/unread-count', notificationController.getUnreadCount);

// Mark all as read
router.patch('/read-all', notificationController.markAllAsRead);

// Delete all read notifications
router.delete('/read', notificationController.deleteAllRead);

// Mark specific notification as read
router.patch('/:notificationId/read', notificationController.markAsRead);

// Delete specific notification
router.delete('/:notificationId', notificationController.deleteNotification);

export default router;
