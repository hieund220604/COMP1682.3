import { Request, Response } from 'express';
import { ResponseUtil } from '../util/responseUtil';
import { budgetService } from '../service/budgetService';
import { AppError } from '../service/receiptService';

export const budgetController = {
    async getMonthlyBudgetSummary(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);
            
            const month = req.query.month as string;
            if (!month) {
                throw new AppError('Month parameter is required (YYYY-MM)', 'VALIDATION_ERROR');
            }

            const summary = await budgetService.getMonthlyBudgetSummary(userId, month);
            ResponseUtil.success(res, summary, 'Budget summary retrieved');
        } catch (error) {
            if (error instanceof AppError) {
                const status = error.status ?? 400;
                ResponseUtil.error(res, error.message, status, error.code, error.details);
                return;
            }
            ResponseUtil.handleError(res, error, 'Failed to get budget summary');
        }
    }
};
