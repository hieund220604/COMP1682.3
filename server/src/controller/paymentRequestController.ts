import { Request, Response } from 'express';
import { paymentRequestService } from '../service/paymentRequestService';
import { ResponseUtil } from '../util/responseUtil';

export const paymentRequestController = {
    /**
     * Create a new payment request
     * POST /api/groups/:groupId/payment-requests
     */
    async createPaymentRequest(req: Request, res: Response): Promise<void> {
        try {
            const { groupId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const request = await paymentRequestService.createPaymentRequest(userId, groupId);
            ResponseUtil.success(res, request, 'Payment request created successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create payment request');
        }
    },

    /**
     * Get all payment requests in group
     * GET /api/groups/:groupId/payment-requests
     */
    async getPaymentRequests(req: Request, res: Response): Promise<void> {
        try {
            const { groupId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const requests = await paymentRequestService.getPaymentRequestsByGroup(userId, groupId);
            ResponseUtil.success(res, requests, 'Payment requests retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get payment requests');
        }
    },

    /**
     * Get payment request by ID with details
     * GET /api/groups/:groupId/payment-requests/:requestId
     */
    async getPaymentRequestById(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, requestId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const request = await paymentRequestService.getPaymentRequestById(userId, groupId, requestId);
            ResponseUtil.success(res, request, 'Payment request retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get payment request');
        }
    },

    /**
     * Cancel payment request
     * POST /api/groups/:groupId/payment-requests/:requestId/cancel
     */
    async cancelPaymentRequest(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, requestId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const result = await paymentRequestService.cancelPaymentRequest(userId, groupId, requestId);
            ResponseUtil.success(res, result, 'Payment request cancelled successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to cancel payment request');
        }
    }
};
