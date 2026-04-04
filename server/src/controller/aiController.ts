import { Request, Response } from 'express';
import { ResponseUtil } from '../util/responseUtil';

const amountRegex = /(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?|\d+(?:[.,]\d+)?)/;
const currencyRegex = /(vnd|vnđ|đ|usd|\$)/i;
const dateRegex = /(\d{1,2}[\/.-]\d{1,2}[\/.-]\d{2,4})/;

export const aiController = {
    async extractInvoice(req: Request, res: Response): Promise<void> {
        const text = typeof req.body?.text === 'string' ? req.body.text.trim() : '';
        const groupId = typeof req.body?.groupId === 'string' ? req.body.groupId : undefined;

        if (!text) {
            return ResponseUtil.validationError(res, 'text is required');
        }

        const amountMatch = text.match(amountRegex);
        const currencyMatch = text.match(currencyRegex);
        const dateMatch = text.match(dateRegex);

        const amountRaw = amountMatch ? amountMatch[1].replace(/,/g, '').replace(/\./g, '.') : undefined;
        const amount = amountRaw ? Number(amountRaw) : undefined;
        const currency = currencyMatch
            ? currencyMatch[1].toUpperCase().replace('VNĐ', 'VND').replace('Đ', 'VND')
            : 'VND';

        const title = text.length > 60 ? text.slice(0, 60) : text;
        const note = text;

        const data = {
            groupId,
            title,
            amount: Number.isFinite(amount) ? amount : undefined,
            currency,
            date: dateMatch ? dateMatch[1] : undefined,
            note
        };

        // TODO: hook real LLM extraction here when available

        ResponseUtil.success(res, { invoice: data }, 'Invoice draft extracted');
    }
};
