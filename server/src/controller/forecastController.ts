// server/src/controller/forecastController.ts
import { Request, Response } from 'express';
import { forecastService } from '../service/forecastService';
import { ResponseUtil } from '../util/responseUtil';

export const forecastController = {
    /**
     * GET /api/forecast?days=30&spendingDays=7
     * Full forecast with daily breakdown + spending insights.
     */
    async getForecast(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const days = Math.min(
                Math.max(1, parseInt((req.query.days as string) ?? '30', 10) || 30),
                90,
            );

            const spendingDays = Math.min(
                Math.max(7, parseInt((req.query.spendingDays as string) ?? '7', 10) || 7),
                60,
            );

            const data = await forecastService.getForecast(userId, days, spendingDays);
            ResponseUtil.success(res, data);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to generate forecast');
        }
    },

    /**
     * GET /api/forecast/summary
     * Lightweight dashboard summary (7-day horizon).
     */
    async getDashboardSummary(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const summary = await forecastService.getDashboardSummary(userId);
            ResponseUtil.success(res, summary);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to generate forecast summary');
        }
    },
};
