import { Request, Response } from 'express';
import { exchangeRateService } from '../service/exchangeRateService';
import { ResponseUtil } from '../util/responseUtil';

export const exchangeRateController = {
    /**
     * Convert currency
     * GET /api/exchange/convert?from=USD&to=VND&amount=100
     */
    async convert(req: Request, res: Response): Promise<void> {
        try {
            const { from, to, amount } = req.query;

            if (!from || !to || !amount) {
                return ResponseUtil.validationError(res, 'from, to, and amount are required');
            }

            const result = await exchangeRateService.convert(
                Number(amount),
                String(from),
                String(to)
            );

            ResponseUtil.success(res, result, 'Currency converted successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to convert currency');
        }
    },

    /**
     * Get exchange rate
     * GET /api/exchange/rate?from=USD&to=VND
     */
    async getRate(req: Request, res: Response): Promise<void> {
        try {
            const { from, to } = req.query;

            if (!from || !to) {
                return ResponseUtil.validationError(res, 'from and to are required');
            }

            const rate = await exchangeRateService.getRate(String(from), String(to));

            ResponseUtil.success(res, {
                fromCurrency: String(from).toUpperCase(),
                toCurrency: String(to).toUpperCase(),
                rate: Math.round(rate * 10000) / 10000
            }, 'Exchange rate retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get exchange rate');
        }
    },

    /**
     * Get supported currencies
     * GET /api/exchange/currencies
     */
    async getSupportedCurrencies(req: Request, res: Response): Promise<void> {
        try {
            const currencies = exchangeRateService.getSupportedCurrencies();
            ResponseUtil.success(res, currencies, 'Supported currencies retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get supported currencies');
        }
    }
};
