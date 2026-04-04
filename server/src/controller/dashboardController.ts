import { Request, Response } from 'express';
import { User } from '../models/User';
import { Transaction } from '../models/Transaction';
import { PaymentRequest } from '../models/PaymentRequest';
import { Transfer } from '../models/Transfer';
import { GroupMember } from '../models/GroupMember';
import { ResponseUtil } from '../util/responseUtil';

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

            // Recent notifications placeholder: top 5 unread count only
            // (Notifications already have dedicated endpoint; here we keep summary)

            // Recent activity: latest 10 transactions
            const recentTx = await Transaction.find({ userId }).sort({ createdAt: -1 }).limit(10);

            ResponseUtil.success(res, {
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
                }))
            });
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to load personal dashboard');
        }
    },

    /**
     * Group dashboard summary
     */
    async getGroupDashboard(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            const { groupId } = req.params;
            if (!userId) return ResponseUtil.unauthorized(res);

            const membership = await GroupMember.findOne({ userId, groupId, leftAt: null });
            if (!membership) return ResponseUtil.forbidden(res, 'Not a member of this group');

            // Open payment requests with progress
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

            // Pending transfers summary
            const pendingTransfers = await Transfer.aggregate([
                { $match: { groupId, status: 'PENDING' } },
                { $group: { _id: null, total: { $sum: '$amount' }, count: { $sum: 1 } } }
            ]);

            // Recent group activity (transfers only, ordered)
            const recentTransfers = await Transfer.find({ groupId }).sort({ createdAt: -1 }).limit(15);

            ResponseUtil.success(res, {
                groupId,
                paymentRequests: prs.map(pr => {
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
                }),
                transfersPending: {
                    totalAmount: pendingTransfers[0]?.total || 0,
                    count: pendingTransfers[0]?.count || 0
                },
                recentTransfers: recentTransfers.map(t => ({
                    id: t._id,
                    fromUserId: t.fromUserId,
                    toUserId: t.toUserId,
                    amount: t.amount,
                    status: t.status,
                    createdAt: t.createdAt
                }))
            });
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to load group dashboard');
        }
    }
};
