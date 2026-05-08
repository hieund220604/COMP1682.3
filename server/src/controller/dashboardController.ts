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
import { originalDebtService } from '../service/originalDebtService';
import { debtSettlementEngine } from '../service/debtSettlementEngine';

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

// ── Helper: Debt Overview (Now serving Group Pending Transfers) ────────────

async function _getDebtOverview(groupId: string) {
    const pendingTransfers = await Transfer.find({ groupId, status: 'PENDING' }).lean();

    let totalOutstanding = 0;
    
    const allUserIds = new Set<string>();
    pendingTransfers.forEach((t: any) => {
        allUserIds.add(t.fromUserId);
        allUserIds.add(t.toUserId);
    });

    const users = allUserIds.size > 0
        ? await User.find({ _id: { $in: Array.from(allUserIds) } }).select('displayName email').lean()
        : [];
    const nameMap = new Map<string, string>();
    users.forEach((u: any) => nameMap.set(u._id.toString(), u.displayName ?? u.email ?? 'Unknown'));

    const simplifiedItems = pendingTransfers.map((t: any) => {
        totalOutstanding += Number(t.amount) || 0;
        return {
            id: t._id,
            debtorId: t.fromUserId,
            debtorName: nameMap.get(t.fromUserId) ?? 'Unknown',
            creditorId: t.toUserId,
            creditorName: nameMap.get(t.toUserId) ?? 'Unknown',
            amount: Number(t.amount) || 0
        };
    });

    return {
        totalOutstanding,
        totalOriginal: totalOutstanding,
        settledPercent: 0,
        items: simplifiedItems,
    };
}

// ── Helper: Upcoming Events ────────────────────────────────────────────────────

async function _getUpcomingEvents(groupId: string) {
    const now = new Date();
    const horizon = new Date(now.getTime() + 14 * 24 * 60 * 60 * 1000); // 14 days

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

    return { paymentRequests };
}
