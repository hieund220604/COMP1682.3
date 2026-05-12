/**
 * Report Service — Financial Report Hub
 *
 * Aggregates data across ALL modules to produce comprehensive financial reports:
 *   - Transactions (all inflow/outflow types)
 *   - Receipts + Tags (personal spending by category)
 *   - BillingHistory (subscription costs)
 *   - Transfers (group expense settlements)
 *   - GroupMember (group activity)
 *   - SubscriptionMember (active subscriptions)
 *
 * Endpoints:
 *   GET /api/reports/monthly?month=2026-05
 *   GET /api/reports/yearly?year=2026
 */

import { Transaction } from '../models/Transaction';
import { Receipt } from '../models/Receipt';
import { ReceiptTag } from '../models/ReceiptTag';
import { BillingHistory } from '../models/BillingHistory';
import { Transfer } from '../models/Transfer';
import { GroupMember } from '../models/GroupMember';
import { Group } from '../models/Group';
import { SubscriptionMember } from '../models/SubscriptionMember';
import { Subscription } from '../models/Subscription';
import { User } from '../models/User';
import { buildRedisKey, getJsonCache, setJsonCache } from '../redis';

// ── Types ──────────────────────────────────────────────────────────────────────

interface BudgetPerformance {
    tagId: string;
    tagName: string;
    tagIcon: string;
    tagColor: string;
    budgetLimit: number | null;
    spent: number;
    receiptCount: number;
    percentUsed: number;
    status: 'UNDER' | 'WARNING' | 'EXCEEDED';
}

interface GroupActivityItem {
    groupId: string;
    groupName: string;
    totalPaid: number;
    totalReceived: number;
    netPosition: number;
    invoiceCount: number;
}

interface SubscriptionSummaryItem {
    name: string;
    amount: number;
    cycle: string;
}

interface MonthlyReport {
    month: string;
    overview: {
        totalInflow: number;
        totalOutflow: number;
        netCashflow: number;
        openingBalance: number;
        closingBalance: number;
        transactionCount: number;
    };
    outflowBySource: {
        personalReceipts: number;
        groupExpenses: number;
        subscriptions: number;
        withdrawals: number;
        other: number;
    };
    inflowBySource: {
        topUps: number;
        groupPaymentsReceived: number;
        refunds: number;
        other: number;
    };
    budgetPerformance: BudgetPerformance[];
    groupActivity: GroupActivityItem[];
    subscriptionSummary: {
        totalCost: number;
        activeCount: number;
        subscriptions: SubscriptionSummaryItem[];
    };
    comparison: {
        previousMonth: {
            totalOutflow: number;
            totalInflow: number;
        };
        changePercent: {
            outflow: number;
            inflow: number;
        };
        trend: 'IMPROVING' | 'STABLE' | 'DECLINING';
    };
    dailySpending: Array<{ date: string; outflow: number; inflow: number }>;
}

interface YearlyReport {
    year: number;
    overview: {
        totalInflow: number;
        totalOutflow: number;
        netCashflow: number;
        avgMonthlyOutflow: number;
        avgMonthlyInflow: number;
    };
    monthlyBreakdown: Array<{
        month: string;
        inflow: number;
        outflow: number;
        net: number;
    }>;
    topCategories: Array<{
        tagName: string;
        tagIcon: string;
        tagColor: string;
        totalSpent: number;
        percent: number;
    }>;
    subscriptionTotal: number;
    groupExpenseTotal: number;
}

// ── Constants ──────────────────────────────────────────────────────────────────

const INFLOW_TYPES = new Set([
    'TOP_UP',
    'TRANSFER_RECEIVED',
    'TRANSFER_REFUND_RECEIVED',
    'REFUND',
    'SETTLEMENT_RECEIVED',
]);

const OUTFLOW_TYPES = new Set([
    'WITHDRAWAL',
    'TRANSFER_SENT',
    'TRANSFER_REFUND_SENT',
    'SUBSCRIPTION_FEE',
    'SETTLEMENT_SENT',
    'EXPENSE_PAYMENT',
    'VNPAY_PAYMENT',
]);

const REPORT_CACHE_TTL = 120; // 2 minutes

// ── Service ────────────────────────────────────────────────────────────────────

export const reportService = {

    /**
     * Generate a comprehensive monthly financial report.
     */
    async getMonthlyReport(userId: string, month: string): Promise<MonthlyReport> {
        // Validate month format
        if (!/^\d{4}-\d{2}$/.test(month)) {
            throw new Error('Invalid month format. Use YYYY-MM');
        }

        // Check cache
        const cacheKey = buildRedisKey('cache', 'report', 'monthly', userId, month);
        const cached = await getJsonCache<MonthlyReport>(cacheKey);
        if (cached) return cached;

        const [year, m] = month.split('-').map(Number);
        const startOfMonth = new Date(Date.UTC(year, m - 1, 1, 0, 0, 0, 0));
        const endOfMonth = new Date(Date.UTC(year, m, 1, 0, 0, 0, 0));

        // Previous month for comparison
        const prevStart = new Date(Date.UTC(year, m - 2, 1, 0, 0, 0, 0));
        const prevEnd = startOfMonth;

        // Run all queries in parallel
        const [
            transactions,
            prevTransactions,
            receiptAgg,
            billingAgg,
            transfersOutAgg,
            transfersInAgg,
            tags,
            activeSubs,
        ] = await Promise.all([
            // Current month transactions
            Transaction.find({
                userId,
                createdAt: { $gte: startOfMonth, $lt: endOfMonth },
            }).lean(),

            // Previous month transactions (for comparison)
            Transaction.find({
                userId,
                createdAt: { $gte: prevStart, $lt: prevEnd },
            }).select('type amount').lean(),

            // Receipt spending aggregation by tag
            Receipt.aggregate([
                { $match: { userId, receiptDate: { $gte: startOfMonth, $lt: endOfMonth } } },
                { $unwind: '$tags' },
                {
                    $group: {
                        _id: '$tags',
                        totalSpent: { $sum: '$totalAmount' },
                        count: { $sum: 1 },
                    },
                },
            ]),

            // Subscription billing costs
            BillingHistory.aggregate([
                { $match: { billingDate: { $gte: startOfMonth, $lt: endOfMonth } } },
                { $unwind: '$memberResults' },
                {
                    $match: {
                        'memberResults.userId': userId,
                        'memberResults.success': true,
                    },
                },
                {
                    $group: {
                        _id: null,
                        totalCost: { $sum: '$memberResults.shareAmount' },
                    },
                },
            ]),

            // Transfers sent (group expenses paid)
            Transfer.aggregate([
                {
                    $match: {
                        fromUserId: userId,
                        status: 'COMPLETED',
                        paidAt: { $gte: startOfMonth, $lt: endOfMonth },
                    },
                },
                {
                    $group: {
                        _id: '$groupId',
                        totalPaid: { $sum: '$amount' },
                        count: { $sum: 1 },
                    },
                },
            ]),

            // Transfers received (group payments received)
            Transfer.aggregate([
                {
                    $match: {
                        toUserId: userId,
                        status: 'COMPLETED',
                        paidAt: { $gte: startOfMonth, $lt: endOfMonth },
                    },
                },
                {
                    $group: {
                        _id: '$groupId',
                        totalReceived: { $sum: '$amount' },
                        count: { $sum: 1 },
                    },
                },
            ]),

            // Tags for budget performance
            ReceiptTag.find({ userId }).lean(),

            // Active subscriptions
            SubscriptionMember.find({ userId, status: 'ACTIVE' })
                .populate<{ subscriptionId: { name: string; amount: number; billingCycle: string; status: string } }>({
                    path: 'subscriptionId',
                    select: 'name amount billingCycle status',
                })
                .lean(),
        ]);

        // ── Process transaction data ──────────────────────────────────────────

        let totalInflow = 0;
        let totalOutflow = 0;
        let topUps = 0;
        let withdrawals = 0;
        let subscriptionFees = 0;
        let transfersSent = 0;
        let transfersReceived = 0;
        let refunds = 0;
        let otherInflow = 0;
        let otherOutflow = 0;

        // Daily spending map
        const dailyMap = new Map<string, { outflow: number; inflow: number }>();

        // Initialize all days of the month
        const daysInMonth = new Date(year, m, 0).getDate();
        for (let d = 1; d <= daysInMonth; d++) {
            const dateKey = `${year}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
            dailyMap.set(dateKey, { outflow: 0, inflow: 0 });
        }

        // Opening/closing balance from first and last transactions
        let openingBalance = 0;
        let closingBalance = 0;

        // Sort transactions by date
        const sortedTx = [...transactions].sort(
            (a: any, b: any) => new Date(a.createdAt).getTime() - new Date(b.createdAt).getTime()
        );

        if (sortedTx.length > 0) {
            openingBalance = Number((sortedTx[0] as any).balanceBefore ?? 0);
            closingBalance = Number((sortedTx[sortedTx.length - 1] as any).balanceAfter ?? 0);
        }

        for (const tx of transactions) {
            const type = (tx as any).type as string;
            const amount = Math.abs(Number((tx as any).amount ?? 0));
            const createdAt = new Date((tx as any).createdAt);
            const dateKey = createdAt.toISOString().slice(0, 10);

            if (INFLOW_TYPES.has(type)) {
                totalInflow += amount;
                const entry = dailyMap.get(dateKey);
                if (entry) entry.inflow += amount;

                switch (type) {
                    case 'TOP_UP':
                        topUps += amount;
                        break;
                    case 'TRANSFER_RECEIVED':
                    case 'SETTLEMENT_RECEIVED':
                        transfersReceived += amount;
                        break;
                    case 'REFUND':
                    case 'TRANSFER_REFUND_RECEIVED':
                        refunds += amount;
                        break;
                    default:
                        otherInflow += amount;
                }
            } else if (OUTFLOW_TYPES.has(type)) {
                totalOutflow += amount;
                const entry = dailyMap.get(dateKey);
                if (entry) entry.outflow += amount;

                switch (type) {
                    case 'WITHDRAWAL':
                        withdrawals += amount;
                        break;
                    case 'SUBSCRIPTION_FEE':
                        subscriptionFees += amount;
                        break;
                    case 'TRANSFER_SENT':
                    case 'SETTLEMENT_SENT':
                    case 'TRANSFER_REFUND_SENT':
                        transfersSent += amount;
                        break;
                    default:
                        otherOutflow += amount;
                }
            }
        }

        // ── Previous month comparison ────────────────────────────────────────

        let prevInflow = 0;
        let prevOutflow = 0;
        for (const tx of prevTransactions) {
            const type = (tx as any).type as string;
            const amount = Math.abs(Number((tx as any).amount ?? 0));
            if (INFLOW_TYPES.has(type)) prevInflow += amount;
            if (OUTFLOW_TYPES.has(type)) prevOutflow += amount;
        }

        const outflowChange = prevOutflow > 0
            ? Math.round(((totalOutflow - prevOutflow) / prevOutflow) * 1000) / 10
            : 0;
        const inflowChange = prevInflow > 0
            ? Math.round(((totalInflow - prevInflow) / prevInflow) * 1000) / 10
            : 0;

        let trend: 'IMPROVING' | 'STABLE' | 'DECLINING';
        const netChange = (totalInflow - totalOutflow) - (prevInflow - prevOutflow);
        if (netChange > prevOutflow * 0.1) trend = 'IMPROVING';
        else if (netChange < -prevOutflow * 0.1) trend = 'DECLINING';
        else trend = 'STABLE';

        // ── Budget performance ───────────────────────────────────────────────

        const receiptSpentMap = new Map<string, { spent: number; count: number }>();
        for (const item of receiptAgg) {
            receiptSpentMap.set(item._id.toString(), {
                spent: item.totalSpent,
                count: item.count,
            });
        }

        const budgetPerformance: BudgetPerformance[] = tags
            .filter((t: any) => !t.isArchived || receiptSpentMap.has(t._id.toString()))
            .map((tag: any) => {
                const data = receiptSpentMap.get(tag._id.toString());
                const spent = data?.spent ?? 0;
                const budget = tag.monthlyBudget ?? null;
                const percentUsed = budget && budget > 0 ? Math.round((spent / budget) * 100) : 0;
                let status: 'UNDER' | 'WARNING' | 'EXCEEDED' = 'UNDER';
                if (budget && budget > 0) {
                    if (spent >= budget) status = 'EXCEEDED';
                    else if (spent >= budget * 0.8) status = 'WARNING';
                }
                return {
                    tagId: tag._id.toString(),
                    tagName: tag.name,
                    tagIcon: tag.icon ?? '📦',
                    tagColor: tag.color,
                    budgetLimit: budget,
                    spent,
                    receiptCount: data?.count ?? 0,
                    percentUsed,
                    status,
                };
            });

        // ── Group activity ───────────────────────────────────────────────────

        // Merge sent and received by group
        const groupMap = new Map<string, { paid: number; received: number; paidCount: number; receivedCount: number }>();
        for (const item of transfersOutAgg) {
            const gid = item._id?.toString() ?? 'unknown';
            const entry = groupMap.get(gid) ?? { paid: 0, received: 0, paidCount: 0, receivedCount: 0 };
            entry.paid += Number(item.totalPaid);
            entry.paidCount += item.count;
            groupMap.set(gid, entry);
        }
        for (const item of transfersInAgg) {
            const gid = item._id?.toString() ?? 'unknown';
            const entry = groupMap.get(gid) ?? { paid: 0, received: 0, paidCount: 0, receivedCount: 0 };
            entry.received += Number(item.totalReceived);
            entry.receivedCount += item.count;
            groupMap.set(gid, entry);
        }

        // Fetch group names
        const groupIds = Array.from(groupMap.keys()).filter(id => id !== 'unknown');
        const groups = groupIds.length > 0
            ? await Group.find({ _id: { $in: groupIds } }).select('name').lean()
            : [];
        const groupNameMap = new Map<string, string>();
        for (const g of groups) {
            groupNameMap.set((g as any)._id.toString(), (g as any).name);
        }

        const groupActivity: GroupActivityItem[] = Array.from(groupMap.entries()).map(([gid, data]) => ({
            groupId: gid,
            groupName: groupNameMap.get(gid) ?? 'Unknown Group',
            totalPaid: Math.round(data.paid * 100) / 100,
            totalReceived: Math.round(data.received * 100) / 100,
            netPosition: Math.round((data.received - data.paid) * 100) / 100,
            invoiceCount: data.paidCount + data.receivedCount,
        }));

        // ── Subscription summary ─────────────────────────────────────────────

        const activeSubItems: SubscriptionSummaryItem[] = [];
        let activeSubCount = 0;
        for (const sm of activeSubs) {
            const sub = (sm as any).subscriptionId;
            if (!sub || sub.status !== 'ACTIVE') continue;
            activeSubCount++;
            activeSubItems.push({
                name: sub.name ?? 'Subscription',
                amount: Number(sub.amount),
                cycle: sub.billingCycle,
            });
        }

        const subBillingTotal = billingAgg.length > 0 ? Number(billingAgg[0].totalCost) : 0;
        // Total receipt spending
        const personalReceiptsTotal = receiptAgg.reduce(
            (sum: number, item: any) => sum + (Number(item.totalSpent) || 0),
            0
        );

        // ── Daily spending array ─────────────────────────────────────────────

        const dailySpending = Array.from(dailyMap.entries())
            .sort(([a], [b]) => a.localeCompare(b))
            .map(([date, data]) => ({
                date,
                outflow: Math.round(data.outflow * 100) / 100,
                inflow: Math.round(data.inflow * 100) / 100,
            }));

        // ── Build response ───────────────────────────────────────────────────

        const report: MonthlyReport = {
            month,
            overview: {
                totalInflow: Math.round(totalInflow * 100) / 100,
                totalOutflow: Math.round(totalOutflow * 100) / 100,
                netCashflow: Math.round((totalInflow - totalOutflow) * 100) / 100,
                openingBalance: Math.round(openingBalance * 100) / 100,
                closingBalance: Math.round(closingBalance * 100) / 100,
                transactionCount: transactions.length,
            },
            outflowBySource: {
                personalReceipts: Math.round(personalReceiptsTotal * 100) / 100,
                groupExpenses: Math.round(transfersSent * 100) / 100,
                subscriptions: Math.round(subscriptionFees * 100) / 100,
                withdrawals: Math.round(withdrawals * 100) / 100,
                other: Math.round(otherOutflow * 100) / 100,
            },
            inflowBySource: {
                topUps: Math.round(topUps * 100) / 100,
                groupPaymentsReceived: Math.round(transfersReceived * 100) / 100,
                refunds: Math.round(refunds * 100) / 100,
                other: Math.round(otherInflow * 100) / 100,
            },
            budgetPerformance,
            groupActivity,
            subscriptionSummary: {
                totalCost: Math.round(subBillingTotal * 100) / 100,
                activeCount: activeSubCount,
                subscriptions: activeSubItems,
            },
            comparison: {
                previousMonth: {
                    totalOutflow: Math.round(prevOutflow * 100) / 100,
                    totalInflow: Math.round(prevInflow * 100) / 100,
                },
                changePercent: {
                    outflow: outflowChange,
                    inflow: inflowChange,
                },
                trend,
            },
            dailySpending,
        };

        await setJsonCache(cacheKey, report, REPORT_CACHE_TTL);
        return report;
    },

    /**
     * Generate a yearly financial report.
     */
    async getYearlyReport(userId: string, year: number): Promise<YearlyReport> {
        const cacheKey = buildRedisKey('cache', 'report', 'yearly', userId, year.toString());
        const cached = await getJsonCache<YearlyReport>(cacheKey);
        if (cached) return cached;

        const startOfYear = new Date(Date.UTC(year, 0, 1, 0, 0, 0, 0));
        const endOfYear = new Date(Date.UTC(year + 1, 0, 1, 0, 0, 0, 0));

        // Fetch all transactions for the year
        const [monthlyAgg, categoryAgg, subTotal, groupTotal] = await Promise.all([
            // Monthly breakdown
            Transaction.aggregate([
                { $match: { userId, createdAt: { $gte: startOfYear, $lt: endOfYear } } },
                {
                    $group: {
                        _id: {
                            month: { $month: '$createdAt' },
                            type: '$type',
                        },
                        total: { $sum: { $toDouble: '$amount' } },
                    },
                },
            ]),

            // Category spending from receipts
            Receipt.aggregate([
                { $match: { userId, receiptDate: { $gte: startOfYear, $lt: endOfYear } } },
                { $unwind: '$tags' },
                {
                    $group: {
                        _id: '$tags',
                        totalSpent: { $sum: '$totalAmount' },
                    },
                },
                { $sort: { totalSpent: -1 } },
                { $limit: 10 },
            ]),

            // Total subscription cost
            BillingHistory.aggregate([
                { $match: { billingDate: { $gte: startOfYear, $lt: endOfYear } } },
                { $unwind: '$memberResults' },
                {
                    $match: {
                        'memberResults.userId': userId,
                        'memberResults.success': true,
                    },
                },
                { $group: { _id: null, total: { $sum: '$memberResults.shareAmount' } } },
            ]),

            // Total group expenses
            Transfer.aggregate([
                {
                    $match: {
                        fromUserId: userId,
                        status: 'COMPLETED',
                        paidAt: { $gte: startOfYear, $lt: endOfYear },
                    },
                },
                { $group: { _id: null, total: { $sum: '$amount' } } },
            ]),
        ]);

        // Build monthly breakdown
        const monthlyData = new Map<number, { inflow: number; outflow: number }>();
        for (let mo = 1; mo <= 12; mo++) {
            monthlyData.set(mo, { inflow: 0, outflow: 0 });
        }

        for (const item of monthlyAgg) {
            const mo = item._id.month;
            const type = item._id.type as string;
            const amount = Math.abs(Number(item.total));
            const entry = monthlyData.get(mo)!;
            if (INFLOW_TYPES.has(type)) entry.inflow += amount;
            if (OUTFLOW_TYPES.has(type)) entry.outflow += amount;
        }

        let totalInflow = 0;
        let totalOutflow = 0;
        const monthlyBreakdown = Array.from(monthlyData.entries())
            .sort(([a], [b]) => a - b)
            .map(([mo, data]) => {
                totalInflow += data.inflow;
                totalOutflow += data.outflow;
                return {
                    month: `${year}-${String(mo).padStart(2, '0')}`,
                    inflow: Math.round(data.inflow * 100) / 100,
                    outflow: Math.round(data.outflow * 100) / 100,
                    net: Math.round((data.inflow - data.outflow) * 100) / 100,
                };
            });

        // Top categories
        const tagIds = categoryAgg.map((c: any) => c._id);
        const tagDocs = tagIds.length > 0
            ? await ReceiptTag.find({ _id: { $in: tagIds } }).lean()
            : [];
        const tagMap = new Map<string, any>();
        for (const t of tagDocs) {
            tagMap.set((t as any)._id.toString(), t);
        }

        const totalCatSpending = categoryAgg.reduce(
            (s: number, c: any) => s + (Number(c.totalSpent) || 0),
            0
        ) || 1;

        const topCategories = categoryAgg.map((c: any) => {
            const tag = tagMap.get(c._id.toString());
            return {
                tagName: tag?.name ?? 'Unknown',
                tagIcon: tag?.icon ?? '📦',
                tagColor: tag?.color ?? '#888888',
                totalSpent: Math.round(Number(c.totalSpent) * 100) / 100,
                percent: Math.round((Number(c.totalSpent) / totalCatSpending) * 100),
            };
        });

        const activeMonths = monthlyBreakdown.filter(mb => mb.outflow > 0 || mb.inflow > 0).length || 1;

        const report: YearlyReport = {
            year,
            overview: {
                totalInflow: Math.round(totalInflow * 100) / 100,
                totalOutflow: Math.round(totalOutflow * 100) / 100,
                netCashflow: Math.round((totalInflow - totalOutflow) * 100) / 100,
                avgMonthlyOutflow: Math.round((totalOutflow / activeMonths) * 100) / 100,
                avgMonthlyInflow: Math.round((totalInflow / activeMonths) * 100) / 100,
            },
            monthlyBreakdown,
            topCategories,
            subscriptionTotal: subTotal.length > 0 ? Math.round(Number(subTotal[0].total) * 100) / 100 : 0,
            groupExpenseTotal: groupTotal.length > 0 ? Math.round(Number(groupTotal[0].total) * 100) / 100 : 0,
        };

        await setJsonCache(cacheKey, report, REPORT_CACHE_TTL);
        return report;
    },
};
