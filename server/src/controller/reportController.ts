import { Request, Response } from 'express';
import { ResponseUtil } from '../util/responseUtil';
import { reportService } from '../service/reportService';

export const reportController = {
    /**
     * GET /api/reports/monthly?month=2026-05
     * Comprehensive monthly financial report.
     */
    async getMonthlyReport(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const month = (req.query.month as string) ?? '';
            if (!/^\d{4}-\d{2}$/.test(month)) {
                return ResponseUtil.validationError(
                    res,
                    'Invalid month format. Use YYYY-MM (e.g. 2026-05)',
                );
            }

            const report = await reportService.getMonthlyReport(userId, month);
            ResponseUtil.success(res, report);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to generate monthly report');
        }
    },

    /**
     * GET /api/reports/yearly?year=2026
     * Yearly financial summary report.
     */
    async getYearlyReport(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const yearStr = (req.query.year as string) ?? '';
            const year = parseInt(yearStr, 10);
            if (!year || year < 2020 || year > 2100) {
                return ResponseUtil.validationError(
                    res,
                    'Invalid year. Provide a valid year between 2020 and 2100.',
                );
            }

            const report = await reportService.getYearlyReport(userId, year);
            ResponseUtil.success(res, report);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to generate yearly report');
        }
    },
};
