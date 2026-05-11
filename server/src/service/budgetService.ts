import { Types } from 'mongoose';
import { Receipt } from '../models/Receipt';
import { ReceiptTag } from '../models/ReceiptTag';
import { BillingHistory } from '../models/BillingHistory';
import { Transfer } from '../models/Transfer';
import { AppError } from './receiptService';
import { Notification, NotificationType } from '../models/Notification';
import { notificationService } from './notificationService';

function toTitleCase(text: string): string {
    return text
        .toLowerCase()
        .split(' ')
        .map(w => w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ');
}

export const budgetService = {
    /**
     * Get monthly spending summary against budget envelopes.
     * Currently aggregates only Receipts. Will be extended to include 
     * Subscription billing and Group transfers.
     */
    async getMonthlyBudgetSummary(userId: string, month: string) {
        if (!/^\d{4}-\d{2}$/.test(month)) {
            throw new AppError('Invalid month format. Use YYYY-MM', 'INVALID_MONTH');
        }
        const [year, m] = month.split('-').map(Number);

        // Start of selected month
        const startOfMonth = new Date(Date.UTC(year, m - 1, 1, 0, 0, 0, 0));
        // Start of next month
        const endOfMonth = new Date(Date.UTC(year, m, 1, 0, 0, 0, 0));

        // 1. Fetch available budget categories (tags)
        // Even archived tags should be checked if they had spending, 
        // but let's fetch all tags that the user owns.
        const tags = await ReceiptTag.find({ userId });

        // 2. Aggregate spending from Receipts
        // Unwind tags because a receipt can belong to multiple categories.
        const receiptAgg = await Receipt.aggregate([
            { $match: { userId, receiptDate: { $gte: startOfMonth, $lt: endOfMonth } } },
            { $unwind: '$tags' },
            { $group: { _id: '$tags', totalSpent: { $sum: '$totalAmount' } } }
        ]);

        const spentMap = new Map<string, number>();
        for (const item of receiptAgg) {
            spentMap.set(item._id.toString(), item.totalSpent);
        }

        // 3. Aggregate from subscriptions
        const subAgg = await BillingHistory.aggregate([
            { $match: { billingDate: { $gte: startOfMonth, $lt: endOfMonth } } },
            { $unwind: '$memberResults' },
            { $match: { 'memberResults.userId': userId, 'memberResults.success': true, 'memberResults.categoryTagId': { $ne: null } } },
            { $group: { _id: '$memberResults.categoryTagId', totalSpent: { $sum: '$memberResults.shareAmount' } } }
        ]);

        for (const item of subAgg) {
            if (item._id) {
                const current = spentMap.get(item._id.toString()) || 0;
                spentMap.set(item._id.toString(), current + item.totalSpent);
            }
        }

        // 4. Aggregate from Transfers
        const transferAgg = await Transfer.aggregate([
            { $match: { fromUserId: userId, status: 'COMPLETED', paidAt: { $gte: startOfMonth, $lt: endOfMonth }, categoryTagId: { $ne: null } } },
            { $group: { _id: '$categoryTagId', totalSpent: { $sum: '$amount' } } }
        ]);

        for (const item of transferAgg) {
            if (item._id) {
                const current = spentMap.get(item._id.toString()) || 0;
                spentMap.set(item._id.toString(), current + item.totalSpent);
            }
        }

        // 5. Map the results to envelopes
        const envelopes = tags.map(tag => {
            const spent = spentMap.get(tag._id.toString()) || 0;
            const budget = tag.monthlyBudget ?? null;

            return {
                tagId: tag._id.toString(),
                name: tag.name,
                icon: tag.icon,
                color: tag.color,
                isArchived: tag.isArchived,
                monthlyBudget: budget,
                spent: spent,
            };
        });

        // Filter out archived tags that have 0 spending
        return envelopes.filter(e => !e.isArchived || e.spent > 0);
    },

    /**
     * Check current month's budget and send alerts if approaching or exceeding limit.
     */
    async checkBudgetAlerts(userId: string): Promise<void> {
        try {
            const now = new Date();
            const monthStr = `${now.getUTCFullYear()}-${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
            const summary = await this.getMonthlyBudgetSummary(userId, monthStr);

            for (const envelope of summary) {
                if (envelope.monthlyBudget && envelope.monthlyBudget > 0) {
                    const ratio = envelope.spent / envelope.monthlyBudget;
                    if (ratio >= 0.8) {
                        let threshold = 80;
                        if (ratio >= 1.0) threshold = 100;
                        else if (ratio >= 0.9) threshold = 90;

                        // Check if an alert for this tag, month, and threshold was already sent
                        const alreadySent = await Notification.exists({
                            userId,
                            type: NotificationType.BUDGET_ALERT,
                            'data.tagId': envelope.tagId,
                            'data.month': monthStr,
                            'data.threshold': { $gte: threshold }
                        });

                        if (!alreadySent) {
                            const title = threshold >= 100
                                ? `Budget Exceeded: ${toTitleCase(envelope.name)}`
                                : `Budget Nearing Limit: ${toTitleCase(envelope.name)}`;
                            const message = threshold >= 100 
                                ? `You have spent ${envelope.spent}, which exceeds your ${envelope.monthlyBudget} limit.`
                                : `You have spent ${Math.round(ratio * 100)}% of your limit.`;

                            await notificationService.notify(
                                userId,
                                NotificationType.BUDGET_ALERT,
                                title,
                                message,
                                {
                                    tagId: envelope.tagId,
                                    month: monthStr,
                                    threshold,
                                    spent: envelope.spent,
                                    budget: envelope.monthlyBudget
                                }
                            );
                        }
                    }
                }
            }
        } catch (error) {
            console.error('Error checking budget alerts:', error);
        }
    }
};
