import { Request, Response } from 'express';
import { User } from '../models/User';
import { Transaction } from '../models/Transaction';
import { PaymentRequest } from '../models/PaymentRequest';
import { Transfer } from '../models/Transfer';
import { GroupMember } from '../models/GroupMember';
import { Invoice } from '../models/Invoice';
import { OriginalDebt } from '../models/OriginalDebt';
import { Subscription } from '../models/Subscription';
import { SubscriptionMember } from '../models/SubscriptionMember';
import { ResponseUtil } from '../util/responseUtil';
import { forecastService } from '../service/forecastService';
import { buildRedisKey, getJsonCache, setJsonCache } from '../redis';

const inflowTypes = new Set([
    'TOP_UP',
    'TRANSFER_RECEIVED',
    'TRANSFER_REFUND_RECEIVED',
    'REFUND',
    'SETTLEMENT_RECEIVED'
]);

const outflowTypes = new Set([
    'WITHDRAWAL',
    'TRANSFER_SENT',
    'TRANSFER_REFUND_SENT',
    'SUBSCRIPTION_FEE',
    'SETTLEMENT_SENT',
    'EXPENSE_PAYMENT',
    'VNPAY_PAYMENT'
]);

export const dashboardController = {
    /**
     * Personal dashboard summary
     */
    async getPersonalDashboard(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) {
                return ResponseUtil.unauthorized(res);
            }

            const cacheKey = buildRedisKey('cache', 'dashboard', 'personal', userId);
            const cached = await getJsonCache(cacheKey);
            if (cached) {
                return ResponseUtil.success(res, cached);
            }

            const user = await User.findById(userId).select('balance currency displayName');

            // Cashflow last 7 days
            const fromDate = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
            const txLast7d = await Transaction.find({
                userId,
                createdAt: { $gte: fromDate }
            }).sort({ createdAt: -1 }).limit(200);

            let inflow = 0;
            let outflow = 0;
            txLast7d.forEach(t => {
                if (inflowTypes.has(t.type)) inflow += Number(t.amount);
                if (outflowTypes.has(t.type)) outflow += Number(t.amount);
            });

            // Debts (pending transfers)
            const [youOweSum, theyOweSum] = await Promise.all([
                Transfer.aggregate([
                    { $match: { fromUserId: userId, status: 'PENDING' } },
                    { $group: { _id: null, total: { $sum: '$amount' } } }
                ]),
                Transfer.aggregate([
                    { $match: { toUserId: userId, status: 'PENDING' } },
                    { $group: { _id: null, total: { $sum: '$amount' } } }
                ])
            ]);

            const youOwe = youOweSum[0]?.total || 0;
            const theyOwe = theyOweSum[0]?.total || 0;

            // Payment requests open related to user groups
            const memberships = await GroupMember.find({ userId, leftAt: null }).select('groupId');
            const groupIds = memberships.map(m => m.groupId);
            const openPRs = groupIds.length === 0 ? [] : await PaymentRequest.find({
                groupId: { $in: groupIds },
                status: { $in: ['ISSUED', 'PARTIALLY_PAID'] }
            }).sort({ issuedAt: -1 }).limit(5);

            // Recent activity: latest 10 transactions
            const recentTx = await Transaction.find({ userId }).sort({ createdAt: -1 }).limit(10);

            // Forecast summary (non-blocking — fail silently)
            let forecastSummary = null;
            try {
                forecastSummary = await forecastService.getDashboardSummary(userId);
            } catch {
                // forecast failure should not break the dashboard
            }

            const responseData = {
                user: {
                    id: user?._id,
                    displayName: user?.displayName,
                    balance: user?.balance ?? 0,
                    currency: user?.currency ?? 'VND'
                },
                cashflow7d: {
                    inflow,
                    outflow
                },
                debts: {
                    youOwe,
                    theyOwe
                },
                openPaymentRequests: openPRs.map(pr => ({
                    id: pr._id,
                    groupId: pr.groupId,
                    status: pr.status,
                    issuedAt: pr.issuedAt,
                    expiresAt: (pr as any).expiresAt ?? null
                })),
                recentTransactions: recentTx.map(tx => ({
                    id: tx._id,
                    type: tx.type,
                    amount: tx.amount,
                    currency: tx.currency,
                    createdAt: tx.createdAt,
                    description: tx.description
                })),
                forecastSummary,
            };

            await setJsonCache(cacheKey, responseData, 60);
            ResponseUtil.success(res, responseData);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to load personal dashboard');
        }
    },

    /**
     * Group dashboard summary
     * GET /dashboard/group/:groupId?months=6
     */
    async getGroupDashboard(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            const { groupId } = req.params;
            if (!userId) return ResponseUtil.unauthorized(res);

            const months = Math.min(
                Math.max(3, parseInt((req.query.months as string) ?? '6', 10) || 6),
                12,
            );

            const membership = await GroupMember.findOne({ userId, groupId, leftAt: null });
            if (!membership) return ResponseUtil.forbidden(res, 'Not a member of this group');

            const cacheKey = buildRedisKey('cache', 'dashboard', 'group', groupId, 'months', months.toString());
            const cached = await getJsonCache(cacheKey);
            if (cached) {
                return ResponseUtil.success(res, cached);
            }

            // Run all queries in parallel for performance
            const [
                prs,
                pendingTransfers,
                recentTransfers,
                spendingData,
                debtsData,
                upcomingData,
            ] = await Promise.all([
                // ── Existing: Payment requests with progress ──
                _getPaymentRequests(groupId),
                // ── Existing: Pending transfers summary ──
                Transfer.aggregate([
                    { $match: { groupId, status: 'PENDING' } },
                    { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } }
                ]),
                // ── Existing: Recent transfers ──
                Transfer.find({ groupId }).sort({ createdAt: -1 }).limit(15).lean(),
                // ── NEW: Spending analytics ──
                _getSpendingAnalytics(groupId, months),
                // ── NEW: Debt overview ──
                _getDebtOverview(groupId),
                // ── NEW: Upcoming events ──
                _getUpcomingEvents(groupId),
            ]);

            const responseData = {
                groupId,
                paymentRequests: prs,
                transfersPending: {
                    totalAmount: pendingTransfers[0]?.total || 0,
                    count: pendingTransfers[0]?.count || 0
                },
                recentTransfers: recentTransfers.map(t => ({
                    id: t._id,
                    fromUserId: (t as any).fromUserId,
                    toUserId: (t as any).toUserId,
                    amount: (t as any).amount,
                    status: (t as any).status,
                    createdAt: (t as any).createdAt
                })),
                spending: spendingData,
                debts: debtsData,
                upcoming: upcomingData,
            };

            await setJsonCache(cacheKey, responseData, 60);
            ResponseUtil.success(res, responseData);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to load group dashboard');
        }
    }
};

// ── Helper: Payment Requests with transfer progress ────────────────────────────

async function _getPaymentRequests(groupId: string) {
    const prs = await PaymentRequest.find({
        groupId,
        status: { $in: ['ISSUED', 'PARTIALLY_PAID'] }
    }).sort({ issuedAt: -1 });

    const prIds = prs.map(pr => pr._id.toString());
    const transfersByPr = prIds.length === 0 ? [] : await Transfer.aggregate([
        { $match: { paymentRequestId: { $in: prIds } } },
        {
            $group: {
                _id: '$paymentRequestId',
                total: { $sum: '$amount' },
                completed: { $sum: { $cond: [{ $eq: ['$status', 'COMPLETED'] }, '$amount', 0] } },
                pending: { $sum: { $cond: [{ $eq: ['$status', 'PENDING'] }, '$amount', 0] } }
            }
        }
    ]);
    const prAggMap = new Map<string, any>();
    transfersByPr.forEach(t => prAggMap.set(t._id, t));

    return prs.map(pr => {
        const agg = prAggMap.get(pr._id.toString());
        return {
            id: pr._id,
            status: pr.status,
            issuedAt: pr.issuedAt,
            expiresAt: (pr as any).expiresAt ?? null,
            totalAmount: agg?.total ?? 0,
            collectedAmount: agg?.completed ?? 0,
            pendingAmount: agg?.pending ?? 0
        };
    });
}

// ── Helper: Spending Analytics ─────────────────────────────────────────────────

async function _getSpendingAnalytics(groupId: string, months: number) {
    const now = new Date();
    const cutoff = new Date(now.getFullYear(), now.getMonth() - months, 1);

    // Monthly trend aggregation
    const monthlyAgg = await Invoice.aggregate([
        {
            $match: {
                groupId,
                status: { $in: ['SUBMITTED', 'LOCKED'] },
                invoiceDate: { $gte: cutoff },
            }
        },
        {
            $group: {
                _id: {
                    year: { $year: '$invoiceDate' },
                    month: { $month: '$invoiceDate' },
                },
                total: { $sum: '$amountTotal' },
                count: { $sum: 1 },
            }
        },
        { $sort: { '_id.year': 1, '_id.month': 1 } },
    ]);

    // Build monthly trend array with all months filled
    const monthlyTrend: Array<{ month: string; total: number; count: number }> = [];
    for (let i = months - 1; i >= 0; i--) {
        const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
        const key = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`;
        const found = monthlyAgg.find(
            (m: any) => m._id.year === d.getFullYear() && m._id.month === d.getMonth() + 1
        );
        monthlyTrend.push({
            month: key,
            total: found?.total ?? 0,
            count: found?.count ?? 0,
        });
    }

    // This month vs last month
    const thisMonthData = monthlyTrend[monthlyTrend.length - 1];
    const lastMonthData = monthlyTrend.length >= 2 ? monthlyTrend[monthlyTrend.length - 2] : null;
    const thisMonth = thisMonthData?.total ?? 0;
    const lastMonth = lastMonthData?.total ?? 0;
    const changePercent = lastMonth > 0
        ? Math.round(((thisMonth - lastMonth) / lastMonth) * 100 * 10) / 10
        : 0;
    const trend: 'UP' | 'DOWN' | 'STABLE' =
        changePercent > 10 ? 'UP' : changePercent < -10 ? 'DOWN' : 'STABLE';

    // All-time total
    const allTimeAgg = await Invoice.aggregate([
        { $match: { groupId, status: { $in: ['SUBMITTED', 'LOCKED'] } } },
        { $group: { _id: null, total: { $sum: '$amountTotal' } } },
    ]);
    const totalAllTime = allTimeAgg[0]?.total ?? 0;

    // By-member breakdown
    const memberAgg = await Invoice.aggregate([
        { $match: { groupId, status: { $in: ['SUBMITTED', 'LOCKED'] } } },
        {
            $group: {
                _id: '$uploadedBy',
                total: { $sum: '$amountTotal' },
                invoiceCount: { $sum: 1 },
            }
        },
        { $sort: { total: -1 } },
    ]);

    // Resolve member names
    const userIds = memberAgg.map((m: any) => m._id);
    const users = userIds.length > 0
        ? await User.find({ _id: { $in: userIds } }).select('displayName email').lean()
        : [];
    const userMap = new Map<string, string>();
    users.forEach((u: any) => userMap.set(u._id.toString(), u.displayName ?? u.email ?? 'Unknown'));

    const totalForPercent = totalAllTime || 1;
    const byMember = memberAgg.map((m: any) => ({
        userId: m._id,
        displayName: userMap.get(m._id) ?? 'Unknown',
        total: m.total,
        percent: Math.round((m.total / totalForPercent) * 100),
        invoiceCount: m.invoiceCount,
    }));

    return {
        totalAllTime,
        thisMonth,
        lastMonth,
        changePercent,
        trend,
        months,
        monthlyTrend,
        byMember,
    };
}

// ── Helper: Debt Overview ──────────────────────────────────────────────────────

async function _getDebtOverview(groupId: string) {
    const debts = await OriginalDebt.find({
        groupId,
        remainingAmount: { $gt: 0 },
    }).lean();

    // Resolve user names
    const allUserIds = new Set<string>();
    debts.forEach((d: any) => {
        allUserIds.add(d.debtorId);
        allUserIds.add(d.creditorId);
    });
    const users = allUserIds.size > 0
        ? await User.find({ _id: { $in: Array.from(allUserIds) } }).select('displayName email').lean()
        : [];
    const nameMap = new Map<string, string>();
    users.forEach((u: any) => nameMap.set(u._id.toString(), u.displayName ?? u.email ?? 'Unknown'));

    // Aggregate debts per debtor→creditor pair
    const pairMap = new Map<string, { debtorId: string; creditorId: string; amount: number }>();
    let totalOutstanding = 0;
    let totalOriginal = 0;

    debts.forEach((d: any) => {
        const key = `${d.debtorId}_${d.creditorId}`;
        const existing = pairMap.get(key);
        if (existing) {
            existing.amount += d.remainingAmount;
        } else {
            pairMap.set(key, {
                debtorId: d.debtorId,
                creditorId: d.creditorId,
                amount: d.remainingAmount,
            });
        }
        totalOutstanding += d.remainingAmount;
        totalOriginal += d.originalAmount;
    });

    const settledPercent = totalOriginal > 0
        ? Math.round(((totalOriginal - totalOutstanding) / totalOriginal) * 100)
        : 100;

    const items = Array.from(pairMap.values())
        .sort((a, b) => b.amount - a.amount)
        .map(d => ({
            debtorId: d.debtorId,
            debtorName: nameMap.get(d.debtorId) ?? 'Unknown',
            creditorId: d.creditorId,
            creditorName: nameMap.get(d.creditorId) ?? 'Unknown',
            amount: d.amount,
        }));

    return {
        totalOutstanding,
        totalOriginal,
        settledPercent,
        items,
    };
}

// ── Helper: Upcoming Events ────────────────────────────────────────────────────

async function _getUpcomingEvents(groupId: string) {
    const now = new Date();
    const horizon = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000); // 14 days

    // Upcoming subscriptions
    const activeSubs = await Subscription.find({ groupId, status: 'ACTIVE' }).lean();
    const subIds = activeSubs.map((s: any) => s._id.toString());

    const upcomingMembers = subIds.length > 0
        ? await SubscriptionMember.find({
            subscriptionId: { $in: subIds },
            status: 'ACTIVE',
            nextBillingDate: { $lte: horizon },
        }).lean()
        : [];

    // Group by subscription
    const subMemberMap = new Map<string, { count: number; nextDate: Date | null; totalAmount: number }>();
    upcomingMembers.forEach((m: any) => {
        const sid = m.subscriptionId;
        const existing = subMemberMap.get(sid);
        if (existing) {
            existing.count++;
            existing.totalAmount += Number(m.amount);
            if (!existing.nextDate || m.nextBillingDate < existing.nextDate) {
                existing.nextDate = m.nextBillingDate;
            }
        } else {
            subMemberMap.set(sid, {
                count: 1,
                totalAmount: Number(m.amount),
                nextDate: m.nextBillingDate,
            });
        }
    });

    const subscriptions = activeSubs
        .filter((s: any) => subMemberMap.has(s._id.toString()))
        .map((s: any) => {
            const data = subMemberMap.get(s._id.toString())!;
            return {
                id: s._id,
                name: s.name,
                nextBillingDate: data.nextDate?.toISOString() ?? null,
                totalAmount: data.totalAmount,
                memberCount: data.count,
                billingCycle: s.billingCycle,
            };
        })
        .sort((a: any, b: any) => {
            if (!a.nextBillingDate) return 1;
            if (!b.nextBillingDate) return -1;
            return a.nextBillingDate.localeCompare(b.nextBillingDate);
        });

    // Expiring payment requests
    const expiringPRs = await PaymentRequest.find({
        groupId,
        status: { $in: ['ISSUED', 'PARTIALLY_PAID'] },
        expiresAt: { $lte: horizon, $gte: now },
    }).sort({ expiresAt: 1 }).limit(5).lean();

    const paymentRequests = expiringPRs.map((pr: any) => ({
        id: pr._id,
        status: pr.status,
        expiresAt: pr.expiresAt,
        daysLeft: Math.ceil((new Date(pr.expiresAt).getTime() - now.getTime()) / (24 * 60 * 60 * 1000)),
    }));

    return { subscriptions, paymentRequests };
}
