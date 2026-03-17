import { PaymentRequest, PaymentRequestStatus } from '../models/PaymentRequest';
import { Invoice } from '../models/Invoice';
import { Transfer } from '../models/Transfer';
import { TransferDebtAllocation } from '../models/TransferDebtAllocation';
import { GroupMember } from '../models/GroupMember';
import { Group } from '../models/Group';
import { User } from '../models/User';
import { originalDebtService } from './originalDebtService';
import { transactionService } from './transactionService';
import { exchangeRateService } from './exchangeRateService';
import { OriginalDebt } from '../models/OriginalDebt';
import { debtSettlementEngine, RawDebt } from './debtSettlementEngine';
import {
    PaymentRequestResponse,
    PaymentRequestDetailResponse,
    UserPaymentBreakdown,
    TransferSummary
} from '../type/paymentRequest';
import { UserSummary, UserDebtBreakdown } from '../type/invoice';
import { TransactionType } from '../type/transaction';
import mongoose from 'mongoose';
import { acquireLock } from '../util/lock';
import { buildRedisKey, deleteKeysByPrefix, getJsonCache, setJsonCache } from '../redis';

const transformUser = (user: any): UserSummary => ({
    id: user._id.toString(),
    displayName: user.displayName,
    avatarUrl: user.avatarUrl
});

// Transfer + allocation types now come from debtSettlementEngine

const PAYMENT_REQUEST_DETAIL_CACHE_TTL_SECONDS = 45;
const PAYMENT_REQUEST_LIST_CACHE_TTL_SECONDS = 30;

function paymentRequestDetailCacheKey(userId: string, groupId: string, requestId: string): string {
    return buildRedisKey('cache', 'payment_request', groupId, 'detail', userId, requestId);
}

function paymentRequestListCacheKey(userId: string, groupId: string): string {
    return buildRedisKey('cache', 'payment_request', groupId, 'list', userId);
}

async function invalidatePaymentRequestCache(groupId: string): Promise<void> {
    await deleteKeysByPrefix(buildRedisKey('cache', 'payment_request', groupId));
}

async function invalidateRelatedInvoiceCache(groupId: string): Promise<void> {
    await deleteKeysByPrefix(buildRedisKey('cache', 'invoice', groupId));
}

export const paymentRequestService = {
    /**
     * Create a new payment request
     * - Locks all submitted invoices
     * - Runs optimization algorithm
     * - Creates transfers with debt allocations
     */
    async createPaymentRequest(userId: string, groupId: string): Promise<PaymentRequestDetailResponse> {
        // Verify user is OWNER or ADMIN
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }
        if (membership.role !== 'OWNER' && membership.role !== 'ADMIN') {
            throw new Error('Only OWNER or ADMIN can create payment requests');
        }

        // Acquire short lock to avoid concurrent creations
        const lock = await acquireLock('payment_request', groupId, 10_000);
        if (!lock) {
            throw new Error('Another payment request is being created. Please retry in a few seconds.');
        }

        const session = await mongoose.startSession();
        try {
            const result = await session.withTransaction(async () => {
                // Check if there's already an open request (inside txn)
                const existingRequest = await PaymentRequest.findOne({
                    groupId,
                    status: { $in: ['ISSUED', 'PARTIALLY_PAID'] }
                }).session(session);
                if (existingRequest) {
                    throw new Error('There is already an open payment request. Please complete or cancel it first.');
                }

                // Get group for baseCurrency
                const group = await Group.findById(groupId).session(session);
                if (!group) throw new Error('Group not found');
                const baseCurrency = group.baseCurrency || 'VND';

                // Get all unlocked, submitted invoices
                const invoices = await Invoice.find({
                    groupId,
                    status: 'SUBMITTED',
                    isLocked: false
                }).session(session);

                if (invoices.length === 0) {
                    throw new Error('No submitted invoices available for payment request');
                }

                const invoiceIds = invoices.map(inv => inv._id.toString());

                // Exchange rate info is now locked at invoice/debt creation time.
                // We still check for foreign currency invoices to populate Transfer display fields.
                const foreignInvoices = invoices.filter(inv => inv.exchangeRate && inv.baseCurrency && inv.currency !== baseCurrency);
                let exchangeRateInfo: { originalCurrency: string; exchangeRate: number } | null = null;

                if (foreignInvoices.length > 0) {
                    // Use the locked rate from the first foreign invoice for Transfer display
                    const firstForeign = foreignInvoices[0];
                    const allSameForeignCurrency = foreignInvoices.every(inv => inv.currency === firstForeign.currency);

                    if (allSameForeignCurrency) {
                        exchangeRateInfo = {
                            originalCurrency: firstForeign.currency,
                            exchangeRate: firstForeign.exchangeRate!
                        };
                    }
                }

                // Get all remaining net balances
                const netBalances = await originalDebtService.getNetBalances(groupId);

                // Get raw pairwise debts for strategy auto-detection (MinCostFlow vs Greedy)
                const rawDebtDocs = await OriginalDebt.find({
                    groupId,
                    remainingAmount: { $gt: 0.01 }
                });
                const rawDebts: RawDebt[] = rawDebtDocs.map(d => ({
                    debtorId: d.debtorId,
                    creditorId: d.creditorId,
                    remainingAmount: d.remainingAmount
                }));

                // Engine automatically selects Greedy or MinCostFlow, then allocates debts via FIFO
                const transfers = await debtSettlementEngine.settle(groupId, netBalances, rawDebts);

                if (transfers.length === 0) {
                    throw new Error('No transfers needed - all balances are settled');
                }

                // Create payment request
                const paymentRequest = await PaymentRequest.create([{
                    groupId,
                    createdBy: userId,
                    invoiceIds,
                    status: 'ISSUED',
                    issuedAt: new Date()
                }], { session }).then(res => res[0]);

                // Lock all invoices
                await Invoice.updateMany(
                    { _id: { $in: invoiceIds } },
                    {
                        isLocked: true,
                        status: 'LOCKED',
                        paymentRequestId: paymentRequest._id.toString()
                    },
                    { session }
                );

                // Create transfers with currency info
                for (const transfer of transfers) {
                    const transferData: any = {
                        paymentRequestId: paymentRequest._id.toString(),
                        groupId,
                        fromUserId: transfer.fromUserId,
                        toUserId: transfer.toUserId,
                        amount: transfer.amount,
                        convertedCurrency: baseCurrency,
                        status: 'PENDING'
                    };

                    // If there's currency conversion, store original currency info
                    if (exchangeRateInfo) {
                        transferData.originalCurrency = exchangeRateInfo.originalCurrency;
                        transferData.originalAmount = Math.round((transfer.amount / exchangeRateInfo.exchangeRate) * 100) / 100;
                        transferData.exchangeRate = exchangeRateInfo.exchangeRate;
                    }

                    const createdTransfer = await Transfer.create([transferData], { session }).then(res => res[0]);

                    // Create debt allocations
                    if (transfer.debtAllocations.length > 0) {
                        await TransferDebtAllocation.insertMany(
                            transfer.debtAllocations.map(alloc => ({
                                transferId: createdTransfer._id.toString(),
                                originalDebtId: alloc.originalDebtId,
                                allocatedAmount: alloc.amount
                            })), { session }
                        );
                    }
                }

                return paymentRequest._id.toString();
            });

            // result is paymentRequestId
            await invalidatePaymentRequestCache(groupId);
            await invalidateRelatedInvoiceCache(groupId);
            return this.getPaymentRequestById(userId, groupId, result!);
        } finally {
            await session.endSession();
            await lock.release();
        }
    },

    /**
     * Get payment request by ID with full details
     */
    async getPaymentRequestById(
        userId: string,
        groupId: string,
        requestId: string
    ): Promise<PaymentRequestDetailResponse> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }

        const cacheKey = paymentRequestDetailCacheKey(userId, groupId, requestId);
        const cached = await getJsonCache<PaymentRequestDetailResponse>(cacheKey);
        if (cached) {
            return cached;
        }

        const request = await PaymentRequest.findOne({ _id: requestId, groupId });
        if (!request) {
            throw new Error('Payment request not found');
        }

        const creator = await User.findById(request.createdBy);
        const transfers = await Transfer.find({ paymentRequestId: requestId });

        // Calculate totals
        const totalAmount = transfers.reduce((sum, t) => sum + t.amount, 0);
        const completedTransfers = transfers.filter(t => t.status === 'COMPLETED').length;

        // Get user breakdowns
        const memberIds = new Set<string>();
        transfers.forEach(t => {
            memberIds.add(t.fromUserId);
            memberIds.add(t.toUserId);
        });

        const users = await User.find({ _id: { $in: Array.from(memberIds) } });
        const userMap = new Map(users.map(u => [u._id.toString(), u]));

        // Build transfer summaries
        const transferSummaries: TransferSummary[] = transfers.map(t => ({
            id: t._id.toString(),
            fromUser: userMap.get(t.fromUserId) ? transformUser(userMap.get(t.fromUserId)) : { id: t.fromUserId, displayName: null, avatarUrl: null },
            toUser: userMap.get(t.toUserId) ? transformUser(userMap.get(t.toUserId)) : { id: t.toUserId, displayName: null, avatarUrl: null },
            amount: t.amount,
            status: t.status,
            paidAt: t.paidAt ?? undefined,
            originalCurrency: t.originalCurrency ?? undefined,
            originalAmount: t.originalAmount ?? undefined,
            convertedCurrency: t.convertedCurrency ?? undefined,
            exchangeRate: t.exchangeRate ?? undefined
        }));

        // Build user breakdowns
        const userBreakdowns: UserPaymentBreakdown[] = [];
        for (const [uid, user] of userMap) {
            const balance = await originalDebtService.getUserNetBalance(groupId, uid);
            userBreakdowns.push({
                user: transformUser(user),
                netBalance: balance.netBalance,
                debts: balance.breakdown
            });
        }

        const response: PaymentRequestDetailResponse = {
            id: request._id.toString(),
            groupId: request.groupId,
            createdBy: creator ? transformUser(creator) : { id: request.createdBy, displayName: null, avatarUrl: null },
            invoiceIds: request.invoiceIds,
            status: request.status,
            issuedAt: request.issuedAt,
            paidAt: request.paidAt ?? undefined,
            cancelledAt: request.cancelledAt ?? undefined,
            createdAt: request.createdAt,
            totalAmount,
            totalTransfers: transfers.length,
            completedTransfers,
            userBreakdowns,
            transfers: transferSummaries
        };

        await setJsonCache(cacheKey, response, PAYMENT_REQUEST_DETAIL_CACHE_TTL_SECONDS);
        return response;
    },

    /**
     * Get all payment requests for a group
     */
    async getPaymentRequestsByGroup(userId: string, groupId: string): Promise<PaymentRequestResponse[]> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }

        const cacheKey = paymentRequestListCacheKey(userId, groupId);
        const cached = await getJsonCache<PaymentRequestResponse[]>(cacheKey);
        if (cached) {
            return cached;
        }

        const requests = await PaymentRequest.find({ groupId }).sort({ createdAt: -1 });

        const result = await Promise.all(requests.map(async (req) => {
            const creator = await User.findById(req.createdBy);
            const transfers = await Transfer.find({ paymentRequestId: req._id.toString() });
            const totalAmount = transfers.reduce((sum, t) => sum + t.amount, 0);
            const completedTransfers = transfers.filter(t => t.status === 'COMPLETED').length;

            return {
                id: req._id.toString(),
                groupId: req.groupId,
                createdBy: creator ? transformUser(creator) : { id: req.createdBy, displayName: null, avatarUrl: null },
                invoiceIds: req.invoiceIds,
                status: req.status,
                issuedAt: req.issuedAt,
                paidAt: req.paidAt ?? undefined,
                cancelledAt: req.cancelledAt ?? undefined,
                createdAt: req.createdAt,
                totalAmount,
                totalTransfers: transfers.length,
                completedTransfers
            };
        }));

        await setJsonCache(cacheKey, result, PAYMENT_REQUEST_LIST_CACHE_TTL_SECONDS);
        return result;
    },

    /**
     * Cancel payment request (supports ISSUED and PARTIALLY_PAID)
     * - ISSUED: just cancel pending transfers  
     * - PARTIALLY_PAID: refund completed transfers, cancel pending ones
     */
    async cancelPaymentRequest(userId: string, groupId: string, requestId: string): Promise<{ refundedTransfers: number; cancelledTransfers: number }> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }
        if (membership.role !== 'OWNER' && membership.role !== 'ADMIN') {
            // Regular members can trigger cancel if they have a pending transfer
            const userHasPendingTransfer = await Transfer.findOne({
                paymentRequestId: requestId,
                fromUserId: userId,
                status: 'PENDING'
            });
            if (!userHasPendingTransfer) {
                throw new Error('Only the payer with a pending transfer or group admin can cancel');
            }
        }

        const request = await PaymentRequest.findOne({ _id: requestId, groupId });
        if (!request) {
            throw new Error('Payment request not found');
        }

        if (request.status !== 'ISSUED' && request.status !== 'PARTIALLY_PAID') {
            throw new Error('Can only cancel ISSUED or PARTIALLY_PAID payment requests');
        }

        const transfers = await Transfer.find({ paymentRequestId: requestId });
        const completedTransfers = transfers.filter(t => t.status === 'COMPLETED');
        const pendingTransfers = transfers.filter(t => t.status === 'PENDING');

        const session = await mongoose.startSession();
        let refundedCount = 0;
        let cancelledCount = 0;

        // Collect refund info for transaction records (created outside txn)
        const refundRecords: Array<{
            fromUserId: string;
            toUserId: string;
            amount: number;
            transferId: string;
            newFromBalance: number;
            newToBalance: number;
        }> = [];

        try {
            await session.withTransaction(async () => {
                // 1. Refund completed transfers
                for (const transfer of completedTransfers) {
                    const amount = Number(transfer.amount);

                    // Refund: return money to sender, deduct from receiver
                    const fromUserDoc = await User.findOneAndUpdate(
                        { _id: transfer.fromUserId },
                        { $inc: { balance: amount } },
                        { session, new: true }
                    );
                    const toUserDoc = await User.findOneAndUpdate(
                        { _id: transfer.toUserId },
                        { $inc: { balance: -amount } },
                        { session, new: true }
                    );

                    if (!fromUserDoc || !toUserDoc) {
                        throw new Error(`User not found during refund for transfer ${transfer._id}`);
                    }

                    // Restore original debts from allocations
                    const allocations = await TransferDebtAllocation.find({
                        transferId: transfer._id.toString()
                    }).session(session);

                    for (const alloc of allocations) {
                        await originalDebtService.restoreDebt(
                            alloc.originalDebtId,
                            alloc.allocatedAmount,
                            session
                        );
                    }

                    // Mark transfer as CANCELLED
                    await Transfer.findByIdAndUpdate(
                        transfer._id,
                        { status: 'CANCELLED' },
                        { session }
                    );

                    refundRecords.push({
                        fromUserId: transfer.fromUserId,
                        toUserId: transfer.toUserId,
                        amount,
                        transferId: transfer._id.toString(),
                        newFromBalance: Number(fromUserDoc.balance),
                        newToBalance: Number(toUserDoc.balance),
                    });

                    refundedCount++;
                }

                // 2. Cancel pending transfers
                for (const transfer of pendingTransfers) {
                    await Transfer.findByIdAndUpdate(
                        transfer._id,
                        { status: 'CANCELLED', otp: null, otpExpiresAt: null },
                        { session }
                    );
                    cancelledCount++;
                }

                // 2.5 Clean up TransferDebtAllocation records for ALL cancelled transfers
                // This ensures debts are "clean" and will be properly included
                // in the next payment request's balance calculation
                const allTransferIds = transfers.map(t => t._id.toString());
                await TransferDebtAllocation.deleteMany(
                    { transferId: { $in: allTransferIds } },
                    { session }
                );

                // 3. Unlock invoices
                await Invoice.updateMany(
                    { _id: { $in: request.invoiceIds } },
                    {
                        isLocked: false,
                        status: 'SUBMITTED',
                        paymentRequestId: null
                    },
                    { session }
                );

                // 4. Update request status
                await PaymentRequest.findByIdAndUpdate(
                    requestId,
                    { status: 'CANCELLED', cancelledAt: new Date() },
                    { session }
                );
            });

            // Create refund transaction records (non-critical audit — must not fail the cancel)
            try {
                for (const record of refundRecords) {
                    const [fromUser, toUser] = await Promise.all([
                        User.findById(record.fromUserId),
                        User.findById(record.toUserId)
                    ]);

                    // Transaction: sender gets refund
                    await transactionService.createTransaction({
                        userId: record.fromUserId,
                        groupId,
                        type: TransactionType.TRANSFER_REFUND_RECEIVED,
                        amount: record.amount,
                        balanceBefore: record.newFromBalance - record.amount,
                        balanceAfter: record.newFromBalance,
                        currency: 'VND',
                        description: `Hoan tien tu ${toUser?.displayName || 'User'} (huy payment request)`,
                        referenceId: record.transferId,
                        referenceType: 'TRANSFER'
                    });

                    // Transaction: receiver gets deducted
                    await transactionService.createTransaction({
                        userId: record.toUserId,
                        groupId,
                        type: TransactionType.TRANSFER_REFUND_SENT,
                        amount: record.amount,
                        balanceBefore: record.newToBalance + record.amount,
                        balanceAfter: record.newToBalance,
                        currency: 'VND',
                        description: `Tru tien hoan cho ${fromUser?.displayName || 'User'} (huy payment request)`,
                        referenceId: record.transferId,
                        referenceType: 'TRANSFER'
                    });
                }
            } catch (auditErr) {
                console.error('Failed to create refund transaction records (non-critical):', auditErr);
            }
        } finally {
            session.endSession();
        }

        await invalidatePaymentRequestCache(groupId);
        await invalidateRelatedInvoiceCache(groupId);

        return { refundedTransfers: refundedCount, cancelledTransfers: cancelledCount };
    },

    /**
     * Cancel a single transfer (only PENDING ones)
     * If there are already COMPLETED transfers in the same request,
     * the entire payment request is cancelled with refunds.
     */
    async cancelSingleTransfer(userId: string, transferId: string): Promise<{ fullCancelTriggered: boolean; refundedTransfers?: number; cancelledTransfers?: number }> {
        const transfer = await Transfer.findById(transferId);
        if (!transfer) {
            throw new Error('Transfer not found');
        }

        // Only the debtor or group admin can cancel
        const membership = await GroupMember.findOne({
            groupId: transfer.groupId, userId, leftAt: null
        });
        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }

        if (transfer.fromUserId !== userId && membership.role !== 'OWNER' && membership.role !== 'ADMIN') {
            throw new Error('Only the payer or group admin can cancel a transfer');
        }

        if (transfer.status !== 'PENDING') {
            throw new Error('Can only cancel PENDING transfers');
        }

        // Check if there are already COMPLETED transfers in this payment request
        const allTransfers = await Transfer.find({ paymentRequestId: transfer.paymentRequestId });
        const hasCompletedTransfers = allTransfers.some(t => t.status === 'COMPLETED');

        if (hasCompletedTransfers) {
            // There are completed transfers → cancel the entire request with refunds
            const result = await this.cancelPaymentRequest(userId, transfer.groupId, transfer.paymentRequestId);
            return { fullCancelTriggered: true, ...result };
        }

        // No completed transfers → just cancel this single PENDING transfer
        await Transfer.findByIdAndUpdate(transferId, {
            status: 'CANCELLED',
            otp: null,
            otpExpiresAt: null
        });

        // Update the payment request status
        await this.updateRequestStatus(transfer.paymentRequestId);
        return { fullCancelTriggered: false };
    },

    /**
     * Update request status based on transfer completions
     */
    async updateRequestStatus(requestId: string): Promise<void> {
        const request = await PaymentRequest.findById(requestId);
        if (!request) {
            return;
        }

        const transfers = await Transfer.find({ paymentRequestId: requestId });
        const activeTransfers = transfers.filter(t => t.status !== 'CANCELLED');
        const completedCount = activeTransfers.filter(t => t.status === 'COMPLETED').length;

        let newStatus: PaymentRequestStatus;
        if (activeTransfers.length === 0) {
            // All transfers cancelled
            newStatus = 'CANCELLED';
        } else if (completedCount === 0) {
            newStatus = 'ISSUED';
        } else if (completedCount === activeTransfers.length) {
            newStatus = 'PAID';
        } else {
            newStatus = 'PARTIALLY_PAID';
        }

        const update: any = { status: newStatus };
        if (newStatus === 'PAID') {
            update.paidAt = new Date();
        }
        if (newStatus === 'CANCELLED') {
            update.cancelledAt = new Date();
        }

        // Unlock invoices when request is terminal (PAID or CANCELLED)
        // so they can be used in a new payment request if needed
        if (newStatus === 'CANCELLED' || newStatus === 'PAID') {
            if (request.invoiceIds && request.invoiceIds.length > 0) {
                await Invoice.updateMany(
                    { _id: { $in: request.invoiceIds } },
                    {
                        isLocked: false,
                        status: 'SUBMITTED',
                        paymentRequestId: null
                    }
                );
            }
        }

        await PaymentRequest.findByIdAndUpdate(requestId, update);
        await invalidatePaymentRequestCache(request.groupId);
        await invalidateRelatedInvoiceCache(request.groupId);
    }
};
