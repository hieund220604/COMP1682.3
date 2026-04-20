import { Request, Response } from 'express';
import { ResponseUtil } from '../util/responseUtil';
import { receiptService, AppError } from '../service/receiptService';
import { ReceiptInput, ReceiptUpdateInput } from '../type/receipt';

export const receiptController = {
    async listTags(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);
            const tags = await receiptService.listTags(userId);
            ResponseUtil.success(res, tags, 'Tags retrieved');
        } catch (error) {
            handleControllerError(res, error, 'Failed to list tags');
        }
    },

    async createTag(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);
            const { name, color, monthlyBudget, icon } = req.body;
            const tag = await receiptService.createTag(userId, name, color, monthlyBudget, icon);
            ResponseUtil.created(res, tag, 'Tag created');
        } catch (error) {
            handleControllerError(res, error, 'Failed to create tag');
        }
    },

    async updateTag(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);
            const { id } = req.params;
            const { name, color, monthlyBudget, icon, isArchived } = req.body;
            const tag = await receiptService.updateTag(userId, id, name, color, monthlyBudget, icon, isArchived);
            ResponseUtil.success(res, tag, 'Tag updated');
        } catch (error) {
            handleControllerError(res, error, 'Failed to update tag');
        }
    },

    async deleteTag(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);
            const { id } = req.params;
            await receiptService.deleteTag(userId, id);
            ResponseUtil.noContent(res);
        } catch (error) {
            handleControllerError(res, error, 'Failed to delete tag');
        }
    },

    async createReceipt(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);
            const payload = req.body as ReceiptInput;
            const receipt = await receiptService.createReceipt(userId, payload);
            ResponseUtil.created(res, receipt, 'Receipt created');
        } catch (error) {
            handleControllerError(res, error, 'Failed to create receipt');
        }
    },

    async getMonthSummary(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);
            const { month } = req.query;
            const summary = await receiptService.getMonthSummary(userId, String(month));
            ResponseUtil.success(res, summary, 'Month summary');
        } catch (error) {
            handleControllerError(res, error, 'Failed to get month summary');
        }
    },

    async getDayReceipts(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);
            const { date } = req.params;
            const data = await receiptService.getDayReceipts(userId, date);
            ResponseUtil.success(res, data, 'Receipts fetched');
        } catch (error) {
            handleControllerError(res, error, 'Failed to get day receipts');
        }
    },

    async updateReceipt(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);
            const { id } = req.params;
            const payload = req.body as ReceiptUpdateInput;
            const receipt = await receiptService.updateReceipt(userId, id, payload);
            ResponseUtil.success(res, receipt, 'Receipt updated');
        } catch (error) {
            handleControllerError(res, error, 'Failed to update receipt');
        }
    },

    async deleteReceipt(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);
            const { id } = req.params;
            await receiptService.deleteReceipt(userId, id);
            ResponseUtil.noContent(res);
        } catch (error) {
            handleControllerError(res, error, 'Failed to delete receipt');
        }
    }
};

function handleControllerError(res: Response, error: any, defaultMessage: string): void {
    if (error instanceof AppError) {
        const status = error.status ?? 400;
        return ResponseUtil.error(res, error.message, status, error.code, error.details);
    }
    return ResponseUtil.handleError(res, error, defaultMessage);
}
