import { Request, Response } from 'express';
import { notificationService } from '../service/notificationService';
import { ResponseUtil } from '../util/responseUtil';

export const notificationController = {
    /**
     * Get user notifications
     * GET /api/notifications
     * Query: unreadOnly (boolean), limit (number)
     */
    async getUserNotifications(req: Request, res: Response): Promise<void> {
        try {
            const userId = (req as any).user.userId;
            const unreadOnly = req.query.unreadOnly === 'true';
            const limit = parseInt(req.query.limit as string) || 50;

            const notifications = await notificationService.getUserNotifications(
                userId,
                unreadOnly,
                limit
            );

            ResponseUtil.success(
                res,
                notifications,
                'Notifications retrieved successfully'
            );
        } catch (error) {
            console.error('Error getting notifications:', error);
            ResponseUtil.handleError(res, error);
        }
    },

    /**
     * Get unread notification count
     * GET /api/notifications/unread-count
     */
    async getUnreadCount(req: Request, res: Response): Promise<void> {
        try {
            const userId = (req as any).user.userId;
            const count = await notificationService.getUnreadCount(userId);

            ResponseUtil.success(
                res,
                { count },
                'Unread count retrieved successfully'
            );
        } catch (error) {
            console.error('Error getting unread count:', error);
            ResponseUtil.handleError(res, error);
        }
    },

    /**
     * Mark notification as read
     * PATCH /api/notifications/:notificationId/read
     */
    async markAsRead(req: Request, res: Response): Promise<void> {
        try {
            const { notificationId } = req.params;
            await notificationService.markAsRead(notificationId);

            ResponseUtil.success(
                res,
                null,
                'Notification marked as read'
            );
        } catch (error) {
            console.error('Error marking notification as read:', error);
            ResponseUtil.handleError(res, error);
        }
    },

    /**
     * Mark all notifications as read
     * PATCH /api/notifications/read-all
     */
    async markAllAsRead(req: Request, res: Response): Promise<void> {
        try {
            const userId = (req as any).user.userId;
            await notificationService.markAllAsRead(userId);

            ResponseUtil.success(
                res,
                null,
                'All notifications marked as read'
            );
        } catch (error) {
            console.error('Error marking all as read:', error);
            ResponseUtil.handleError(res, error);
        }
    },

    /**
     * Delete a notification
     * DELETE /api/notifications/:notificationId
     */
    async deleteNotification(req: Request, res: Response): Promise<void> {
        try {
            const { notificationId } = req.params;
            await notificationService.deleteNotification(notificationId);

            ResponseUtil.success(
                res,
                null,
                'Notification deleted successfully'
            );
        } catch (error) {
            console.error('Error deleting notification:', error);
            ResponseUtil.handleError(res, error);
        }
    },

    /**
     * Delete all read notifications
     * DELETE /api/notifications/read
     */
    async deleteAllRead(req: Request, res: Response): Promise<void> {
        try {
            const userId = (req as any).user.userId;
            const count = await notificationService.deleteAllRead(userId);

            ResponseUtil.success(
                res,
                { deletedCount: count },
                `${count} read notification(s) deleted successfully`
            );
        } catch (error) {
            console.error('Error deleting read notifications:', error);
            ResponseUtil.handleError(res, error);
        }
    }
};
