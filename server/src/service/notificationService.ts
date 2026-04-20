import { Notification, NotificationType } from '../models/Notification';
import { User } from '../models/User';
import { emailService } from './emailService';
import { getIO } from '../socketSetup';
import { getMessaging, isFirebaseInitialized } from '../config/firebase';

export interface CreateNotificationInput {
    userId: string;
    type: NotificationType;
    title: string;
    message: string;
    data?: any;
    sendEmail?: boolean;
}

export const notificationService = {
    /**
     * Create a notification and optionally send email
     */
    async createNotification(input: CreateNotificationInput): Promise<void> {
        const notification = await Notification.create({
            userId: input.userId,
            type: input.type,
            title: input.title,
            message: input.message,
            data: input.data,
            sentEmail: false
        });

        // Emit Socket.IO event for real-time notification
        try {
            const io = getIO();
            io.to(`user:${input.userId}`).emit('new_notification', {
                id: notification._id.toString(),
                type: notification.type,
                title: notification.title,
                message: notification.message,
                data: notification.data,
                read: notification.read,
                createdAt: notification.createdAt
            });
        } catch (error) {
            console.error('Failed to emit notification via Socket.IO:', error);
            // Don't throw - notification still created
        }

        // Send FCM push notification if user has FCM token
        try {
            const user = await User.findById(input.userId);
            if (!user) {
                console.warn(`FCM skip: user not found (${input.userId})`);
            } else if (!user.fcmToken) {
                console.log(`FCM skip: user ${input.userId} has no fcmToken`);
            } else if (user.pushNotificationsEnabled === false) {
                console.log(`FCM skip: user ${input.userId} has disabled push notifications`);
            } else if (!isFirebaseInitialized()) {
                console.warn('FCM skip: Firebase Admin is not initialized');
            } else {
                const messaging = getMessaging();
                if (messaging) {
                    const messageId = await messaging.send({
                        token: user.fcmToken,
                        notification: {
                            title: input.title,
                            body: input.message
                        },
                        data: input.data ? {
                            notificationId: notification._id.toString(),
                            type: input.type,
                            ...Object.entries(input.data).reduce((acc, [key, value]) => {
                                acc[key] = typeof value === 'string' ? value : JSON.stringify(value);
                                return acc;
                            }, {} as Record<string, string>)
                        } : undefined,
                        android: {
                            priority: 'high',
                            notification: {
                                sound: 'default'
                            }
                        },
                        apns: {
                            payload: {
                                aps: {
                                    sound: 'default'
                                }
                            }
                        }
                    });
                    console.log(`FCM sent to user ${input.userId}: ${messageId}`);
                } else {
                    console.warn('FCM skip: Firebase messaging instance is unavailable');
                }
            }
        } catch (error: any) {
            // Handle invalid FCM token by clearing it
            if (error?.code === 'messaging/invalid-registration-token' || 
                error?.code === 'messaging/registration-token-not-registered') {
                console.log(`Clearing invalid FCM token for user ${input.userId}`);
                await User.findByIdAndUpdate(input.userId, { fcmToken: null });
            } else {
                console.error('Failed to send FCM notification:', error);
            }
            // Don't throw - notification still created
        }

        // Send email if requested
        if (input.sendEmail) {
            try {
                const user = await User.findById(input.userId);
                if (user && user.email) {
                    await emailService.sendNotificationEmail(
                        user.email,
                        user.displayName || user.email,
                        input.title,
                        input.message
                    );

                    // Mark as sent
                    notification.sentEmail = true;
                    await notification.save();
                }
            } catch (error) {
                console.error('Failed to send notification email:', error);
                // Don't throw - notification still created
            }
        }
    },

    /**
     * Create notifications for multiple users
     */
    async createBulkNotifications(
        userIds: string[],
        type: NotificationType,
        title: string,
        message: string,
        data?: any,
        sendEmail: boolean = false
    ): Promise<void> {
        const promises = userIds.map(userId =>
            this.createNotification({
                userId,
                type,
                title,
                message,
                data,
                sendEmail
            })
        );

        await Promise.all(promises);
    },

    /**
     * Get user notifications
     */
    async getUserNotifications(
        userId: string,
        unreadOnly: boolean = false,
        limit: number = 50
    ): Promise<any[]> {
        const query: any = { userId };
        if (unreadOnly) {
            query.read = false;
        }

        const notifications = await Notification.find(query)
            .sort({ createdAt: -1 })
            .limit(limit);

        return notifications.map(n => ({
            id: n._id.toString(),
            type: n.type,
            title: n.title,
            message: n.message,
            data: n.data,
            read: n.read,
            createdAt: n.createdAt
        }));
    },

    /**
     * Mark notification as read
     */
    async markAsRead(notificationId: string): Promise<void> {
        await Notification.findByIdAndUpdate(notificationId, { read: true });
    },

    /**
     * Mark all user notifications as read
     */
    async markAllAsRead(userId: string): Promise<void> {
        await Notification.updateMany({ userId, read: false }, { read: true });
    },

    /**
     * Get unread count
     */
    async getUnreadCount(userId: string): Promise<number> {
        return await Notification.countDocuments({ userId, read: false });
    },

    /**
     * Delete old notifications (cleanup)
     */
    async deleteOldNotifications(daysOld: number = 30): Promise<number> {
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - daysOld);

        const result = await Notification.deleteMany({
            createdAt: { $lt: cutoffDate },
            read: true
        });

        return result.deletedCount || 0;
    },

    /**
     * Delete a specific notification
     */
    async deleteNotification(notificationId: string): Promise<void> {
        await Notification.findByIdAndDelete(notificationId);
    },

    /**
     * Delete all read notifications for a user
     */
    async deleteAllRead(userId: string): Promise<number> {
        const result = await Notification.deleteMany({
            userId,
            read: true
        });

        return result.deletedCount || 0;
    },

    /**
     * Convenience shorthand with positional args.
     * notify(userId, type, title, message, data?)
     */
    async notify(
        userId: string,
        type: NotificationType,
        title: string,
        message: string,
        data?: any,
    ): Promise<void> {
        return this.createNotification({ userId, type, title, message, data });
    }
};
