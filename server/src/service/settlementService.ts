import { Settlement } from '../models/Settlement';
import { GroupMember } from '../models/GroupMember';
import { User } from '../models/User';
import { Expense } from '../models/Expense';
import { ExpenseShare } from '../models/ExpenseShare';
import { notificationService } from './notificationService';
import { NotificationType } from '../models/Notification';
import {
    CreateSettlementRequest,
    SettlementResponse,
    SuggestedSettlement,
    SettlementStatus,
    UserSummary
} from '../type/settlement';
import { transactionService } from './transactionService';
import { TransactionType } from '../type/transaction';
import mongoose from 'mongoose';
import { Group } from '../models/Group';

function transformUser(user: any): UserSummary {
    return {
        id: user._id.toString(),
        email: user.email,
        displayName: user.displayName ?? undefined,
        avatarUrl: user.avatarUrl ?? undefined
    };
}

export const settlementService = {
    /**
     * Create optimized settlements for a group using optimal DFS algorithm
     * Automatically calculates all debts from ledger and creates minimal settlements
     */
    async createSettlement(userId: string, groupId: string): Promise<SettlementResponse[]> {
        // Verify user is member
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        // Get net balances from ledger
        const { ledgerService } = await import('./ledgerService');
        const { settlementAlgorithm } = await import('./settlementAlgorithm');

        const balances = await ledgerService.getGroupBalances(groupId);

        // Run optimal algorithm
        const transfers = settlementAlgorithm.autoSettle(balances);

        if (transfers.length === 0) {
            throw new Error('No settlements needed - all debts are balanced');
        }

        // Create all settlements
        const createdSettlements: SettlementResponse[] = [];

        for (const transfer of transfers) {
            const settlement = await Settlement.create({
                groupId,
                fromUserId: transfer.fromUserId,
                toUserId: transfer.toUserId,
                amount: transfer.amount,
                currency: 'VND',
                status: 'PENDING',
                note: 'Auto-generated settlement (optimal algorithm)'
            });

            const [fromUser, toUser] = await Promise.all([
                User.findById(transfer.fromUserId).select('_id email displayName avatarUrl'),
                User.findById(transfer.toUserId).select('_id email displayName avatarUrl')
            ]);

            createdSettlements.push({
                id: settlement._id.toString(),
                groupId: settlement.groupId,
                fromUser: transformUser(fromUser!),
                toUser: transformUser(toUser!),
                amount: Number(settlement.amount),
                currency: settlement.currency,
                status: settlement.status as SettlementStatus,
                settlementDate: settlement.settlementDate,
                note: settlement.note ?? undefined,
                vnpayTxnRef: settlement.vnpayTxnRef ?? undefined,
                createdAt: settlement.createdAt
            });

            // Notify the debtor (fromUser) about the new settlement
            await notificationService.createNotification({
                userId: transfer.fromUserId,
                type: NotificationType.SETTLEMENT_CREATED,
                title: 'New Settlement',
                message: `You need to pay ${transfer.amount.toLocaleString()} VND to ${toUser?.displayName || 'someone'}`,
                data: {
                    settlementId: settlement._id.toString(),
                    groupId,
                    amount: transfer.amount,
                    toUserId: transfer.toUserId
                }
            });
        }

        return createdSettlements;
    },

    async getSettlementsByGroup(userId: string, groupId: string): Promise<SettlementResponse[]> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        const settlements = await Settlement.find({ groupId }).sort({ createdAt: -1 });

        const results = await Promise.all(
            settlements.map(async (settlement) => {
                const [fromUser, toUser] = await Promise.all([
                    User.findById(settlement.fromUserId).select('_id email displayName avatarUrl'),
                    User.findById(settlement.toUserId).select('_id email displayName avatarUrl')
                ]);

                return {
                    id: settlement._id.toString(),
                    groupId: settlement.groupId,
                    fromUser: transformUser(fromUser!),
                    toUser: transformUser(toUser!),
                    amount: Number(settlement.amount),
                    currency: settlement.currency,
                    status: settlement.status as SettlementStatus,
                    settlementDate: settlement.settlementDate,
                    note: settlement.note ?? undefined,
                    vnpayTxnRef: settlement.vnpayTxnRef ?? undefined,
                    createdAt: settlement.createdAt
                };
            })
        );

        return results;
    },

    async getSuggestedSettlements(userId: string, groupId: string): Promise<SuggestedSettlement[]> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        const group = await Group.findById(groupId);
        const members = await GroupMember.find({ groupId, leftAt: null });
        const users = await User.find({
            _id: { $in: members.map(m => m.userId) }
        }).select('_id displayName');

        const expenses = await Expense.find({ groupId });
        const expenseIds = expenses.map(e => e._id.toString());
        const shares = await ExpenseShare.find({ expenseId: { $in: expenseIds } });
        const settlements = await Settlement.find({ groupId, status: 'COMPLETED' });

        const balances = new Map<string, number>();
        const names = new Map<string, string>();

        members.forEach(m => {
            balances.set(m.userId, 0);
            const user = users.find(u => u._id.toString() === m.userId);
            names.set(m.userId, user?.displayName || m.userId);
        });

        expenses.forEach(expense => {
            const current = balances.get(expense.paidBy) || 0;
            balances.set(expense.paidBy, current + Number(expense.amountTotal));
        });

        expenses.forEach(expense => {
            const expenseShares = shares.filter(s => s.expenseId === expense._id.toString());
            expenseShares.forEach(share => {
                const current = balances.get(share.userId) || 0;
                balances.set(share.userId, current - Number(share.owedAmount));
            });
        });

        settlements.forEach(s => {
            const fromBalance = balances.get(s.fromUserId) || 0;
            const toBalance = balances.get(s.toUserId) || 0;
            balances.set(s.fromUserId, fromBalance + Number(s.amount));
            balances.set(s.toUserId, toBalance - Number(s.amount));
        });

        const debtors: { userId: string; amount: number }[] = [];
        const creditors: { userId: string; amount: number }[] = [];

        balances.forEach((balance, userId) => {
            if (balance < -0.01) {
                debtors.push({ userId, amount: Math.abs(balance) });
            } else if (balance > 0.01) {
                creditors.push({ userId, amount: balance });
            }
        });

        debtors.sort((a, b) => b.amount - a.amount);
        creditors.sort((a, b) => b.amount - a.amount);

        const suggestions: SuggestedSettlement[] = [];
        let di = 0, ci = 0;

        while (di < debtors.length && ci < creditors.length) {
            const debtor = debtors[di];
            const creditor = creditors[ci];
            const amount = Math.min(debtor.amount, creditor.amount);

            if (amount > 0.01) {
                suggestions.push({
                    fromUserId: debtor.userId,
                    fromUserName: names.get(debtor.userId),
                    toUserId: creditor.userId,
                    toUserName: names.get(creditor.userId),
                    amount: Math.round(amount * 100) / 100,
                    currency: group?.baseCurrency || 'VND'
                });
            }

            debtor.amount -= amount;
            creditor.amount -= amount;

            if (debtor.amount < 0.01) di++;
            if (creditor.amount < 0.01) ci++;
        }

        return suggestions;
    },

    async updateSettlementStatus(settlementId: string, status: SettlementStatus, vnpayTxnRef?: string): Promise<SettlementResponse> {
        const settlement = await Settlement.findById(settlementId);

        if (!settlement) {
            throw new Error('Settlement not found');
        }

        if (status === 'COMPLETED' && settlement.status !== 'COMPLETED') {
            const [fromUser, toUser] = await Promise.all([
                User.findById(settlement.fromUserId),
                User.findById(settlement.toUserId)
            ]);

            if (!fromUser || !toUser) {
                throw new Error('User not found');
            }

            const fromUserBalanceBefore = Number(fromUser.balance);
            const toUserBalanceBefore = Number(toUser.balance);
            const amount = Number(settlement.amount);

            const session = await mongoose.startSession();
            session.startTransaction();

            try {
                await User.findByIdAndUpdate(
                    settlement.fromUserId,
                    { balance: fromUserBalanceBefore - amount },
                    { session }
                );

                await User.findByIdAndUpdate(
                    settlement.toUserId,
                    { balance: toUserBalanceBefore + amount },
                    { session }
                );

                await Settlement.findByIdAndUpdate(
                    settlementId,
                    {
                        status,
                        vnpayTxnRef,
                        vnpayTransDate: new Date()
                    },
                    { session }
                );

                await session.commitTransaction();
            } catch (error) {
                await session.abortTransaction();
                throw error;
            } finally {
                session.endSession();
            }

            const toUserName = toUser.displayName || toUser.email || 'Unknown';
            const fromUserName = fromUser.displayName || fromUser.email || 'Unknown';

            await transactionService.createTransaction({
                userId: settlement.fromUserId,
                groupId: settlement.groupId,
                type: TransactionType.TRANSFER_SENT,
                amount: amount,
                balanceBefore: fromUserBalanceBefore,
                balanceAfter: fromUserBalanceBefore - amount,
                currency: 'VND',
                description: `Trả nợ cho ${toUserName} (VNPay)`,
                referenceId: settlementId,
                referenceType: 'SETTLEMENT',
                metadata: vnpayTxnRef ? { vnpayTxnRef } : undefined
            });

            await transactionService.createTransaction({
                userId: settlement.toUserId,
                groupId: settlement.groupId,
                type: TransactionType.TRANSFER_RECEIVED,
                amount: amount,
                balanceBefore: toUserBalanceBefore,
                balanceAfter: toUserBalanceBefore + amount,
                currency: 'VND',
                description: `Nhận tiền từ ${fromUserName} (VNPay)`,
                referenceId: settlementId,
                referenceType: 'SETTLEMENT',
                metadata: vnpayTxnRef ? { vnpayTxnRef } : undefined
            });
        } else {
            await Settlement.findByIdAndUpdate(settlementId, { status, vnpayTxnRef });
        }

        const result = await this.getSettlementById(settlementId);
        if (!result) {
            throw new Error('Settlement not found after update');
        }
        return result;
    },

    async getSettlementById(settlementId: string): Promise<SettlementResponse | null> {
        const settlement = await Settlement.findById(settlementId);

        if (!settlement) return null;

        const [fromUser, toUser] = await Promise.all([
            User.findById(settlement.fromUserId).select('_id email displayName avatarUrl'),
            User.findById(settlement.toUserId).select('_id email displayName avatarUrl')
        ]);

        return {
            id: settlement._id.toString(),
            groupId: settlement.groupId,
            fromUser: transformUser(fromUser!),
            toUser: transformUser(toUser!),
            amount: Number(settlement.amount),
            currency: settlement.currency,
            status: settlement.status as SettlementStatus,
            settlementDate: settlement.settlementDate,
            note: settlement.note ?? undefined,
            vnpayTxnRef: settlement.vnpayTxnRef ?? undefined,
            createdAt: settlement.createdAt
        };
    },

    async payWithBalance(userId: string, settlementId: string): Promise<any> {
        const settlement = await Settlement.findById(settlementId);

        if (!settlement) {
            throw new Error('Settlement not found');
        }

        if (settlement.fromUserId !== userId) {
            throw new Error('You can only pay settlements where you are the payer');
        }

        if (settlement.status !== 'PENDING') {
            throw new Error('Settlement is not in pending status');
        }

        const user = await User.findById(userId);

        if (!user) {
            throw new Error('User not found');
        }

        const userBalance = Number(user.balance);
        const amount = Number(settlement.amount);

        if (userBalance < amount) {
            throw new Error(`Insufficient balance. Available: ${userBalance}, Required: ${amount}`);
        }

        const recipient = await User.findById(settlement.toUserId);
        const recipientBalanceBefore = Number(recipient?.balance || 0);

        let newBalance = 0;

        const session = await mongoose.startSession();
        try {
            await session.withTransaction(async () => {
                const lockedSettlement = await Settlement.findOneAndUpdate(
                    { _id: settlementId, status: 'PENDING', fromUserId: userId },
                    { status: 'COMPLETED' },
                    { session, new: false }
                );

                if (!lockedSettlement) {
                    throw new Error('Settlement is not pending');
                }

                const payerDoc = await User.findOneAndUpdate(
                    { _id: userId, balance: { $gte: amount } },
                    { $inc: { balance: -amount } },
                    { session, new: false }
                );

                if (!payerDoc) {
                    throw new Error('Insufficient balance');
                }

                const recipientDoc = await User.findOneAndUpdate(
                    { _id: settlement.toUserId },
                    { $inc: { balance: amount } },
                    { session, new: false }
                );

                if (!recipientDoc) {
                    throw new Error('Recipient not found');
                }

                newBalance = Number(payerDoc.balance) - amount;
            });

            const toUser = await User.findById(settlement.toUserId).select('displayName email');
            const toUserName = toUser?.displayName || toUser?.email || 'Unknown';
            const fromUserName = user.displayName || user.email || 'Unknown';

            await transactionService.createTransaction({
                userId: settlement.fromUserId,
                groupId: settlement.groupId,
                type: TransactionType.TRANSFER_SENT,
                amount: amount,
                balanceBefore: userBalance,
                balanceAfter: newBalance,
                currency: 'VND',
                description: `Tra no cho ${toUserName}`,
                referenceId: settlementId,
                referenceType: 'SETTLEMENT'
            });

            await transactionService.createTransaction({
                userId: settlement.toUserId,
                groupId: settlement.groupId,
                type: TransactionType.TRANSFER_RECEIVED,
                amount: amount,
                balanceBefore: recipientBalanceBefore,
                balanceAfter: recipientBalanceBefore + amount,
                currency: 'VND',
                description: `Nhan tu ${fromUserName}`,
                referenceId: settlementId,
                referenceType: 'SETTLEMENT'
            });
        } finally {
            session.endSession();
        }

        const updatedUser = await User.findById(userId);

        return {
            success: true,
            message: 'Payment completed successfully',
            settlementId,
            amountPaid: amount,
            newBalance: Number(updatedUser!.balance)
        };
    },

    async quickPayDebt(userId: string, groupId: string, toUserId: string, amount: number, paymentMethod: 'BALANCE' | 'VNPAY'): Promise<any> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        if (userId === toUserId) {
            throw new Error('Cannot pay yourself');
        }

        const settlement = await Settlement.create({
            groupId,
            fromUserId: userId,
            toUserId,
            amount,
            currency: 'VND',
            status: 'PENDING'
        });

        if (paymentMethod === 'BALANCE') {
            await this.payWithBalance(userId, settlement._id.toString());
            return {
                settlementId: settlement._id.toString(),
                status: 'COMPLETED'
            };
        } else {
            return {
                settlementId: settlement._id.toString(),
                status: 'PENDING'
            };
        }
    },

    /**
     * @deprecated This method uses Expense-based calculation and has been replaced by
     * originalDebtService.getUserDebtsInGroup() which uses OriginalDebt-based calculation.
     * 
     * The OriginalDebt-based approach accurately tracks remaining amounts after partial payments,
     * while this method recalculates from scratch and may produce inconsistent results.
     * 
     * Use originalDebtService.getUserDebtsInGroup() instead for consistent debt calculations
     * across the application.
     * 
     * This method is kept temporarily for comparison during migration but should not be used
     * in production code.
     */
    async getUserDebts(userId: string, groupId: string): Promise<any> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        const group = await Group.findById(groupId);
        const members = await GroupMember.find({ groupId, leftAt: null });
        const users = await User.find({
            _id: { $in: members.map(m => m.userId) }
        }).select('_id displayName avatarUrl');

        const expenses = await Expense.find({ groupId });
        const expenseIds = expenses.map(e => e._id.toString());
        const shares = await ExpenseShare.find({ expenseId: { $in: expenseIds } });
        const settlements = await Settlement.find({ groupId, status: 'COMPLETED' });

        const debt = new Map<string, Map<string, number>>();
        const userInfo = new Map<string, any>();

        members.forEach(m => {
            debt.set(m.userId, new Map());
            const user = users.find(u => u._id.toString() === m.userId);
            userInfo.set(m.userId, {
                displayName: user?.displayName ?? undefined,
                avatarUrl: user?.avatarUrl ?? undefined
            });
        });

        expenses.forEach(expense => {
            const expenseShares = shares.filter(s => s.expenseId === expense._id.toString());
            expenseShares.forEach(share => {
                if (share.userId !== expense.paidBy) {
                    const currentDebt = debt.get(share.userId)?.get(expense.paidBy) || 0;
                    debt.get(share.userId)?.set(expense.paidBy, currentDebt + Number(share.owedAmount));
                }
            });
        });

        settlements.forEach(s => {
            const currentDebt = debt.get(s.fromUserId)?.get(s.toUserId) || 0;
            debt.get(s.fromUserId)?.set(s.toUserId, currentDebt - Number(s.amount));
        });

        const iOwe: any[] = [];
        const oweMe: any[] = [];
        let netBalance = 0;

        members.forEach(m => {
            if (m.userId === userId) return;

            const iOweToThem = debt.get(userId)?.get(m.userId) || 0;
            const theyOweToMe = debt.get(m.userId)?.get(userId) || 0;
            const netAmount = theyOweToMe - iOweToThem;

            if (netAmount > 0.01) {
                oweMe.push({
                    userId: m.userId,
                    displayName: userInfo.get(m.userId)?.displayName,
                    avatarUrl: userInfo.get(m.userId)?.avatarUrl,
                    amount: Math.round(netAmount * 100) / 100
                });
                netBalance += netAmount;
            } else if (netAmount < -0.01) {
                iOwe.push({
                    userId: m.userId,
                    displayName: userInfo.get(m.userId)?.displayName,
                    avatarUrl: userInfo.get(m.userId)?.avatarUrl,
                    amount: Math.round(Math.abs(netAmount) * 100) / 100
                });
                netBalance += netAmount;
            }
        });

        return {
            groupId,
            currency: group?.baseCurrency || 'VND',
            iOwe,
            oweMe,
            netBalance: Math.round(netBalance * 100) / 100
        };
    },

    async getMyPendingDebts(userId: string, groupId: string): Promise<any> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        // Dynamically import Transfer
        const { Transfer } = await import('../models/Transfer');

        const transfers = await Transfer.find({
            groupId,
            fromUserId: userId,
            status: 'PENDING'
        }).sort({ createdAt: -1 });

        const toUserIds = transfers.map(t => t.toUserId);
        const users = await User.find({
            _id: { $in: toUserIds }
        }).select('_id email displayName avatarUrl');

        const userMap = new Map();
        users.forEach(u => userMap.set(u._id.toString(), u));

        const debts = transfers.map(t => ({
            settlementId: t._id.toString(), // Keep field named settlementId for backward compatibility
            toUser: transformUser(userMap.get(t.toUserId)),
            amount: Number(t.amount),
            currency: 'VND',
            status: t.status,
            createdAt: t.createdAt
        }));

        return {
            debts,
            totalAmount: debts.reduce((sum, d) => sum + d.amount, 0)
        };
    },

    async getMyPendingCredits(userId: string, groupId: string): Promise<any> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        // Dynamically import Transfer
        const { Transfer } = await import('../models/Transfer');

        const transfers = await Transfer.find({
            groupId,
            toUserId: userId
        }).sort({ createdAt: -1 });

        const fromUserIds = transfers.map(t => t.fromUserId);
        const users = await User.find({
            _id: { $in: fromUserIds }
        }).select('_id email displayName avatarUrl');

        const userMap = new Map();
        users.forEach(u => userMap.set(u._id.toString(), u));

        const credits = transfers.map(t => ({
            settlementId: t._id.toString(), // Keep field named settlementId for backward compatibility
            fromUser: transformUser(userMap.get(t.fromUserId)),
            amount: Number(t.amount),
            currency: 'VND',
            status: t.status,
            createdAt: t.createdAt
        }));

        return {
            credits,
            totalPending: credits.filter(c => c.status === 'PENDING').reduce((sum, c) => sum + c.amount, 0),
            totalCompleted: credits.filter(c => c.status === 'COMPLETED').reduce((sum, c) => sum + c.amount, 0)
        };
    },

    async getAllUserDebts(userId: string): Promise<any> {
        // Use OriginalDebt-based calculation instead of Expense-based
        const { originalDebtService } = await import('./originalDebtService');
        const summary = await originalDebtService.getUserGlobalDebtSummary(userId);

        return summary;
    }
};
