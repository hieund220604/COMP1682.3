import { Request, Response } from 'express';
import { ResponseUtil } from '../util/responseUtil';
import { AIService } from '../service/aiService';

export const aiController = {
    async extractInvoice(req: Request, res: Response): Promise<void> {
        const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
        const groupId = typeof req.body?.groupId === 'string' ? req.body.groupId : undefined;

        if (!text) {
            return ResponseUtil.validationError(res, 'text is required');
        }

        try {
            const data = await AIService.extractInvoiceData(text, groupId);
            ResponseUtil.success(res, data, 'Invoice draft extracted successfully');
        } catch (error: any) {
            console.error('[AI Controller] Error extracting invoice:', error);
            ResponseUtil.serverError(res, 'Failed to extract invoice data');
        }
    },
    async extractInvoiceFromImage(req: Request, res: Response): Promise<void> {
        if (!req.file || !req.file.buffer) {
            return ResponseUtil.validationError(res, 'file is required');
        }

        try {
            const data = await AIService.extractInvoiceFromImage(
                req.file.buffer,
                req.file.mimetype
            );
            ResponseUtil.success(res, data, 'Invoice OCR extracted successfully');
        } catch (error: any) {
            console.error('[AI Controller] Error extracting OCR invoice:', error);
            ResponseUtil.serverError(res, 'Failed to extract invoice OCR data');
        }
    },
    async generateDebtReminder(req: Request, res: Response): Promise<void> {
        const debtorName = typeof req.body?.debtorName === 'string' ? req.body.debtorName.trim() : '';
        const debts = Array.isArray(req.body?.debts) ? req.body.debts : [];
        const style = typeof req.body?.style === 'string' ? req.body.style.trim() : 'funny';

        if (!debtorName) {
            return ResponseUtil.validationError(res, 'debtorName is required');
        }

        try {
            const message = await AIService.generateDebtReminder({
                debtorName,
                debts,
                style
            });
            ResponseUtil.success(res, { message }, 'Debt reminder generated successfully');
        } catch (error: any) {
            console.error('[AI Controller] Error generating debt reminder:', error);
            ResponseUtil.serverError(res, 'Failed to generate debt reminder');
        }
    }
};
