import { Request, Response } from 'express';
import { transactionService } from '../service/transactionService';
import { ResponseUtil } from '../util/responseUtil';
import { TransactionType } from '../type/transaction';
import { ApiResponse } from '../type/group';

export const transactionController = {
    /**
     * Get current user's transaction history
     * GET /api/transactions
     */
    async getMyTransactions(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const page = parseInt(req.query.page as string) || 1;
            const limit = parseInt(req.query.limit as string) || 20;
            const type = req.query.type as TransactionType | undefined;

            const result = await transactionService.getTransactionsByUser(req.user.userId, { page, limit, type });

            ResponseUtil.success(res, {
                transactions: result.transactions,
                total: result.total,
                page,
                limit
            }, 'Transactions retrieved successfully');

        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get transactions');
        }
    },

    /**
     * Get transactions for a specific group
     * GET /api/groups/:groupId/transactions
     */
    async getGroupTransactions(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { groupId } = req.params;
            const page = parseInt(req.query.page as string) || 1;
            const limit = parseInt(req.query.limit as string) || 20;
            const type = req.query.type as TransactionType | undefined;

            const result = await transactionService.getTransactionsByGroup(req.user.userId, groupId, { page, limit, type });

            ResponseUtil.success(res, {
                transactions: result.transactions,
                total: result.total,
                page,
                limit
            }, 'Group transactions retrieved successfully');

        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get group transactions');
        }
    },

    /**
     * Get a specific transaction by ID
     * GET /api/transactions/:id
     */
    async getTransactionById(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { id } = req.params;

            const transaction = await transactionService.getTransactionById(id, req.user.userId);

            if (!transaction) {
                return ResponseUtil.notFound(res, 'Transaction not found');
            }

            ResponseUtil.success(res, transaction, 'Transaction retrieved successfully');

        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get transaction');
        }
    },

    /**
     * Get user's transaction summary
     * GET /api/transactions/summary
     */
    async getTransactionSummary(
        req: Request,
        res: Response
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const summary = await transactionService.getUserTransactionSummary(req.user.userId);

            ResponseUtil.success(res, summary, 'Transaction summary retrieved successfully');

        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get transaction summary');
        }
    }
};
