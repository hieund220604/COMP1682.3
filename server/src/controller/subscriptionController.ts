import { Request, Response } from 'express';
import { subscriptionService } from '../service/subscriptionService';
import { ResponseUtil } from '../util/responseUtil';

export const subscriptionController = {
    /**
     * Create a new subscription
     * POST /api/subscriptions
     */
    async createSubscription(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { groupId, name, description, amount, billingCycle, startDate } = req.body;

            if (!groupId || !name || !amount || !billingCycle) {
                return ResponseUtil.validationError(res, 'groupId, name, amount, and billingCycle are required');
            }

            const subscription = await subscriptionService.createSubscription(userId, {
                groupId,
                name,
                description,
                amount: Number(amount),
                billingCycle,
                startDate: startDate ? new Date(startDate) : undefined
            });

            ResponseUtil.success(res, subscription, 'Subscription created successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create subscription');
        }
    },

    /**
     * Get all subscriptions for the current user
     * GET /api/subscriptions
     */
    async getSubscriptions(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const subscriptions = await subscriptionService.getSubscriptionsForUser(userId);
            ResponseUtil.success(res, subscriptions, 'Subscriptions retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to fetch subscriptions');
        }
    },

    /**
     * Get subscription by ID
     * GET /api/subscriptions/:id
     */
    async getSubscriptionById(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { id } = req.params;

            const subscription = await subscriptionService.getSubscriptionById(userId, id);
            ResponseUtil.success(res, subscription, 'Subscription retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Subscription not found');
        }
    },

    /**
     * Get billing history for a subscription
     * GET /api/subscriptions/:id/billing-history
     */
    async getBillingHistory(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { id } = req.params;

            const history = await subscriptionService.getBillingHistory(userId, id);
            ResponseUtil.success(res, history, 'Billing history retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to fetch billing history');
        }
    },

    /**
     * Cancel a subscription (OWNER/ADMIN only)
     * POST /api/subscriptions/:id/cancel
     */
    async cancelSubscription(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { id } = req.params;

            const subscription = await subscriptionService.cancelSubscription(userId, id);
            ResponseUtil.success(res, subscription, 'Subscription cancelled successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to cancel subscription');
        }
    },

    /**
     * Member leaves a subscription without leaving the group
     * POST /api/subscriptions/:id/leave
     */
    async leaveSubscription(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { id } = req.params;

            await subscriptionService.leaveSubscription(userId, id);
            ResponseUtil.success(res, null, 'Successfully left the subscription');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to leave subscription');
        }
    },

    /**
     * Pause an active subscription (OWNER/ADMIN only)
     * POST /api/subscriptions/:id/pause
     */
    async pauseSubscription(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { id } = req.params;

            const subscription = await subscriptionService.pauseSubscription(userId, id);
            ResponseUtil.success(res, subscription, 'Subscription paused successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to pause subscription');
        }
    },

    /**
     * Update a subscription (OWNER/ADMIN only)
     * PATCH /api/subscriptions/:id
     */
    async updateSubscription(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { id } = req.params;

            const subscription = await subscriptionService.updateSubscription(userId, id, req.body);
            ResponseUtil.success(res, subscription, 'Subscription updated successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to update subscription');
        }
    },

    /**
     * Resume a cancelled/past_due/paused subscription (OWNER/ADMIN only)
     * POST /api/subscriptions/:id/resume
     */
    async resumeSubscription(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { id } = req.params;

            const subscription = await subscriptionService.resumeSubscription(userId, id);
            ResponseUtil.success(res, subscription, 'Subscription resumed successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to resume subscription');
        }
    },

    /**
     * Process recurring charges (called by cron job or admin)
     * POST /api/subscriptions/process-charges
     */
    async processCharges(req: Request, res: Response) {
        try {
            const result = await subscriptionService.processRenewals();
            ResponseUtil.success(res, result, 'Recurring charges processed successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to process recurring charges');
        }
    }
};
