import { Request, Response } from 'express';
import { invoiceService } from '../service/invoiceService';
import { originalDebtService } from '../service/originalDebtService';
import { InvoiceStatus } from '../models/Invoice';
import { ResponseUtil } from '../util/responseUtil';

export const invoiceController = {
    /**
     * Create a new invoice
     * POST /api/groups/:groupId/invoices
     */
    async createInvoice(req: Request, res: Response): Promise<void> {
        try {
            const { groupId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const invoice = await invoiceService.createInvoice(userId, groupId, req.body);
            ResponseUtil.success(res, invoice, 'Invoice created successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create invoice');
        }
    },



    /**
     * Search invoices in group
     */
    async searchInvoices(req: Request, res: Response): Promise<void> {
        try {
            const { groupId } = req.params;
            const userId = req.user?.userId;
            const query = req.query.search as string | undefined;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const page = req.query.page ? parseInt(req.query.page as string) : 1;
            const limit = req.query.limit ? parseInt(req.query.limit as string) : 10;
            const status = req.query.status as InvoiceStatus | undefined;
            const sortBy = req.query.sortBy as string | undefined;
            const sortOrder = req.query.sortOrder as string | undefined;

            const invoices = await invoiceService.searchInvoices(userId, groupId, query || '', status, sortBy, sortOrder, page, limit);
            ResponseUtil.success(res, invoices, 'Invoices retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to search invoices');
        }
    },

    /**
     * Get all invoices in group
     * GET /api/groups/:groupId/invoices
     */
    async getInvoices(req: Request, res: Response): Promise<void> {
        try {
            const { groupId } = req.params;
            const userId = req.user?.userId;
            const status = req.query.status as InvoiceStatus | undefined;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const invoices = await invoiceService.getInvoicesByGroup(userId, groupId, status);
            ResponseUtil.success(res, invoices, 'Invoices retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get invoices');
        }
    },

    /**
     * Get invoice by ID
     * GET /api/groups/:groupId/invoices/:invoiceId
     */
    async getInvoiceById(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, invoiceId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const invoice = await invoiceService.getInvoiceById(userId, groupId, invoiceId);
            ResponseUtil.success(res, invoice, 'Invoice retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get invoice');
        }
    },

    /**
     * Update invoice
     * PUT /api/groups/:groupId/invoices/:invoiceId
     */
    async updateInvoice(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, invoiceId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const invoice = await invoiceService.updateInvoice(userId, groupId, invoiceId, req.body);
            ResponseUtil.success(res, invoice, 'Invoice updated successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to update invoice');
        }
    },

    /**
     * Delete invoice
     * DELETE /api/groups/:groupId/invoices/:invoiceId
     */
    async deleteInvoice(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, invoiceId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            await invoiceService.deleteInvoice(userId, groupId, invoiceId);
            ResponseUtil.success(res, null, 'Invoice deleted successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to delete invoice');
        }
    },

    /**
     * Submit invoice (creates original debts)
     * POST /api/groups/:groupId/invoices/:invoiceId/submit
     */
    async submitInvoice(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, invoiceId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const invoice = await invoiceService.submitInvoice(userId, groupId, invoiceId);
            ResponseUtil.success(res, invoice, 'Invoice submitted successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to submit invoice');
        }
    },

    /**
     * Get user's net balance in group
     * GET /api/groups/:groupId/my-balance
     */
    async getMyBalance(req: Request, res: Response): Promise<void> {
        try {
            const { groupId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const balance = await originalDebtService.getUserNetBalance(groupId, userId);
            ResponseUtil.success(res, balance, 'Balance retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get balance');
        }
    },

    /**
     * Create adjustment invoice
     * POST /api/groups/:groupId/invoices/:invoiceId/adjust
     */
    async createAdjustmentInvoice(req: Request, res: Response): Promise<void> {
        try {
            const { groupId, invoiceId } = req.params;
            const userId = req.user?.userId;

            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const invoice = await invoiceService.createAdjustmentInvoice(userId, groupId, invoiceId, req.body);
            ResponseUtil.success(res, invoice, 'Adjustment invoice created successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create adjustment invoice');
        }
    }
};
