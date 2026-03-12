import { Request, Response } from 'express';
import { expenseService } from '../service/expenseService';
import { ResponseUtil } from '../util/responseUtil';
import {
    CreateExpenseRequest,
    UpdateExpenseRequest,
    ExpenseResponse
} from '../type/expense';
import { ApiResponse, PaginationMeta } from '../type/group';

export const expenseController = {
    async createExpense(
        req: Request<{ groupId: string }, {}, CreateExpenseRequest>,
        res: Response<ApiResponse<ExpenseResponse>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { groupId } = req.params;
            const { title, amountTotal, splitType, shares, items } = req.body;

            if (!title || !amountTotal || !splitType) {
                return ResponseUtil.validationError(res, 'Title, amount and split type are required');
            }

            // Validate: ITEM_BASED requires items, other types require shares
            if (splitType === 'ITEM_BASED') {
                if (!items || items.length === 0) {
                    return ResponseUtil.validationError(res, 'Items are required for ITEM_BASED split type');
                }
            } else {
                if (!shares || shares.length === 0) {
                    return ResponseUtil.validationError(res, 'Shares are required for this split type');
                }
            }

            const expense = await expenseService.createExpense(req.user.userId, groupId, req.body);
            ResponseUtil.success(res, expense, 'Expense created successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create expense');
        }
    },

    async getExpenseById(
        req: Request<{ groupId: string; expenseId: string }>,
        res: Response<ApiResponse<ExpenseResponse>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { groupId, expenseId } = req.params;
            const expense = await expenseService.getExpenseById(req.user.userId, groupId, expenseId);
            ResponseUtil.success(res, expense, 'Expense retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get expense');
        }
    },

    async getExpensesByGroup(
        req: Request<{ groupId: string }>,
        res: Response<ApiResponse<ExpenseResponse[]>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { groupId } = req.params;
            const page = parseInt(req.query.page as string) || 1;
            const limit = parseInt(req.query.limit as string) || 20;

            const { expenses, total } = await expenseService.getExpensesByGroup(req.user.userId, groupId, page, limit);

            const meta: PaginationMeta = {
                page,
                limit,
                total,
                totalPages: Math.ceil(total / limit)
            };

            ResponseUtil.success(res, { expenses, meta }, 'Expenses retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get expenses');
        }
    },

    async updateExpense(
        req: Request<{ groupId: string; expenseId: string }, {}, UpdateExpenseRequest>,
        res: Response<ApiResponse<ExpenseResponse>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { groupId, expenseId } = req.params;
            const expense = await expenseService.updateExpense(req.user.userId, groupId, expenseId, req.body);
            ResponseUtil.success(res, expense, 'Expense updated successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to update expense');
        }
    },

    async deleteExpense(
        req: Request<{ groupId: string; expenseId: string }>,
        res: Response<ApiResponse<null>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { groupId, expenseId } = req.params;
            await expenseService.deleteExpense(req.user.userId, groupId, expenseId);
            ResponseUtil.success(res, null, 'Expense deleted successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to delete expense');
        }
    }
};
