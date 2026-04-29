import { Request, Response } from 'express';
import { recurringBillService } from '../service/recurringBillService';
import { ResponseUtil } from '../util/responseUtil';

export const billTemplateController = {

    /**
     * POST /api/groups/:groupId/bill-templates
     */
    async createTemplate(req: Request, res: Response): Promise<void> {
        try {
            const { groupId } = req.params;
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const template = await recurringBillService.createTemplate(userId, groupId, req.body);
            ResponseUtil.success(res, template, 'Bill template created successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create bill template');
        }
    },

    /**
     * GET /api/groups/:groupId/bill-templates
     */
    async getTemplates(req: Request, res: Response): Promise<void> {
        try {
            const { groupId } = req.params;
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const templates = await recurringBillService.getTemplates(userId, groupId);
            ResponseUtil.success(res, templates, 'Bill templates retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get bill templates');
        }
    },

    /**
     * GET /api/groups/:groupId/bill-templates/:templateId
     */
    async getTemplateById(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, templateId } = req.params;
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const template = await recurringBillService.getTemplateById(userId, groupId, templateId);
            ResponseUtil.success(res, template, 'Bill template retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get bill template');
        }
    },

    /**
     * PUT /api/groups/:groupId/bill-templates/:templateId
     */
    async updateTemplate(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, templateId } = req.params;
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const template = await recurringBillService.updateTemplate(userId, groupId, templateId, req.body);
            ResponseUtil.success(res, template, 'Bill template updated successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to update bill template');
        }
    },

    /**
     * PATCH /api/groups/:groupId/bill-templates/:templateId/pause
     */
    async pauseTemplate(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, templateId } = req.params;
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            await recurringBillService.pauseTemplate(userId, groupId, templateId);
            ResponseUtil.success(res, null, 'Bill template paused successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to pause bill template');
        }
    },

    /**
     * PATCH /api/groups/:groupId/bill-templates/:templateId/resume
     */
    async resumeTemplate(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, templateId } = req.params;
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            await recurringBillService.resumeTemplate(userId, groupId, templateId);
            ResponseUtil.success(res, null, 'Bill template resumed successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to resume bill template');
        }
    },

    /**
     * DELETE /api/groups/:groupId/bill-templates/:templateId
     */
    async archiveTemplate(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, templateId } = req.params;
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            await recurringBillService.archiveTemplate(userId, groupId, templateId);
            ResponseUtil.success(res, null, 'Bill template archived successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to archive bill template');
        }
    },

    /**
     * POST /api/groups/:groupId/bill-templates/:templateId/generate-now
     */
    async generateNow(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, templateId } = req.params;
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const invoice = await recurringBillService.generateNow(userId, groupId, templateId);
            ResponseUtil.success(res, invoice, 'Invoice generated successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to generate invoice');
        }
    },

    /**
     * POST /api/groups/:groupId/invoices/:invoiceId/confirm
     * Confirm a DRAFT invoice → SUBMITTED
     */
    async confirmDraft(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, invoiceId } = req.params;
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const invoice = await recurringBillService.confirmDraft(userId, groupId, invoiceId);
            ResponseUtil.success(res, invoice, 'Invoice confirmed successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to confirm invoice');
        }
    },
};
