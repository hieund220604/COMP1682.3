import { Request, Response } from 'express';
import { subscriptionService } from '../service/subscriptionService';
import { ResponseUtil } from '../util/responseUtil';

export const subscriptionController = {

    /** POST /api/subscriptions */
    async createSubscription(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { groupId, name, description, amount, billingCycle } = req.body;

            if (!groupId || !name || !amount || !billingCycle) {
                return ResponseUtil.validationError(res, 'groupId, name, amount, and billingCycle are required');
            }

            const subscription = await subscriptionService.createSubscription(userId, {
                groupId,
                name,
                description,
                amount: Number(amount),
                billingCycle,
            });
            ResponseUtil.success(res, subscription, 'Subscription created successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create subscription');
        }
    },

    /** GET /api/subscriptions */
    async getSubscriptions(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const subscriptions = await subscriptionService.getSubscriptionsForUser(userId);
            ResponseUtil.success(res, subscriptions, 'Subscriptions retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to fetch subscriptions');
        }
    },

    /** GET /api/subscriptions/:id */
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

    /** GET /api/subscriptions/:id/members */
    async getMembers(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { id } = req.params;
            const result = await subscriptionService.getMembers(userId, id);
            ResponseUtil.success(res, result, 'Members retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to fetch members');
        }
    },

    /** GET /api/subscriptions/:id/billing-history */
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

    /** POST /api/subscriptions/:id/invite */
    async inviteMember(req: Request, res: Response) {
        try {
            const ownerId = (req as any).user.userId;
            const { id } = req.params;
            const { inviteeId } = req.body;

            if (!inviteeId) {
                return ResponseUtil.validationError(res, 'inviteeId is required');
            }

            const invitation = await subscriptionService.inviteMember(ownerId, id, inviteeId);
            ResponseUtil.success(res, invitation, 'Invitation sent successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to send invitation');
        }
    },

    /** POST /api/subscriptions/:id/invite/respond */
    async respondToInvitation(req: Request, res: Response) {
        try {
            const userId = (req as any).user.userId;
            const { invitationId, accept, categoryTagId } = req.body;

            if (!invitationId || accept === undefined) {
                return ResponseUtil.validationError(res, 'invitationId and accept (boolean) are required');
            }

            await subscriptionService.respondToInvitation(userId, invitationId, Boolean(accept), categoryTagId);
            ResponseUtil.success(res, null, accept ? 'Joined subscription successfully' : 'Invitation declined');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to respond to invitation');
        }
    },

    /** POST /api/subscriptions/:id/cancel */
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

    /** POST /api/subscriptions/:id/leave */
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

    /** POST /api/subscriptions/process-charges (cron) */
    async processCharges(req: Request, res: Response) {
        try {
            const result = await subscriptionService.processRenewals();
            ResponseUtil.success(res, result, 'Renewals processed successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to process renewals');
        }
    },
};
