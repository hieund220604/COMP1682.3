import { Expense } from '../models/Expense';
import { ExpenseShare } from '../models/ExpenseShare';
import { ExpenseItem } from '../models/ExpenseItem';
import { GroupMember } from '../models/GroupMember';
import { User } from '../models/User';
import { notificationService } from './notificationService';
import { NotificationType } from '../models/Notification';
import {
    CreateExpenseRequest,
    UpdateExpenseRequest,
    ExpenseResponse,
    ExpenseItemInput,
    SplitType,
    UserSummary
} from '../type/expense';
import mongoose from 'mongoose';

function transformUser(user: any): UserSummary {
    return {
        id: user._id.toString(),
        email: user.email,
        displayName: user.displayName ?? undefined,
        avatarUrl: user.avatarUrl ?? undefined
    };
}

function calculateShares(
    amountTotal: number,
    splitType: SplitType,
    shares: { userId: string; amount?: number; percent?: number }[]
): { userId: string; owedAmount: number }[] {
    switch (splitType) {
        case SplitType.EQUAL:
            const equalAmount = amountTotal / shares.length;
            return shares.map(s => ({
                userId: s.userId,
                owedAmount: Math.round(equalAmount * 100) / 100
            }));

        case SplitType.EXACT:
            return shares.map(s => ({
                userId: s.userId,
                owedAmount: s.amount || 0
            }));

        case SplitType.PERCENT:
            return shares.map(s => ({
                userId: s.userId,
                owedAmount: Math.round((amountTotal * (s.percent || 0) / 100) * 100) / 100
            }));

        default:
            throw new Error('Invalid split type');
    }
}

function calculateSharesFromItems(
    items: ExpenseItemInput[],
    payerId: string
): { userId: string; owedAmount: number }[] {
    const userTotals = new Map<string, number>();

    for (const item of items) {
        if (item.assignedTo === payerId) {
            continue;
        }
        const itemTotal = item.price * (item.quantity || 1);
        const current = userTotals.get(item.assignedTo) || 0;
        userTotals.set(item.assignedTo, current + itemTotal);
    }

    return Array.from(userTotals.entries()).map(([userId, owedAmount]) => ({
        userId,
        owedAmount: Math.round(owedAmount * 100) / 100
    }));
}

export const expenseService = {
    async createExpense(userId: string, groupId: string, data: CreateExpenseRequest): Promise<ExpenseResponse> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        const memberIds = await GroupMember.find({ groupId, leftAt: null }).select('userId');
        const validMemberIds = new Set(memberIds.map(m => m.userId));

        let calculatedShares: { userId: string; owedAmount: number }[] = [];
        let itemsToCreate: { name: string; price: number; quantity: number; assignedTo: string }[] = [];

        if (data.splitType === SplitType.ITEM_BASED) {
            if (!data.items || data.items.length === 0) {
                throw new Error('At least one item is required for item-based split');
            }

            for (const item of data.items) {
                if (!validMemberIds.has(item.assignedTo)) {
                    throw new Error(`User ${item.assignedTo} is not a member of this group`);
                }
            }

            calculatedShares = calculateSharesFromItems(data.items, userId);
            itemsToCreate = data.items.map(item => ({
                name: item.name,
                price: item.price,
                quantity: item.quantity || 1,
                assignedTo: item.assignedTo
            }));
        } else {
            if (!data.shares || data.shares.length === 0) {
                throw new Error('At least one share is required');
            }

            for (const share of data.shares) {
                if (!validMemberIds.has(share.userId)) {
                    throw new Error(`User ${share.userId} is not a member of this group`);
                }
            }

            calculatedShares = calculateShares(data.amountTotal, data.splitType, data.shares);

            if (data.splitType === SplitType.EXACT) {
                const totalShares = calculatedShares.reduce((sum, s) => sum + s.owedAmount, 0);
                if (Math.abs(totalShares - data.amountTotal) > 1) {
                    throw new Error('Sum of shares must equal total amount');
                }
            }

            if (data.splitType === SplitType.PERCENT) {
                const totalPercent = data.shares.reduce((sum, s) => sum + (s.percent || 0), 0);
                if (Math.abs(totalPercent - 100) > 0.01) {
                    throw new Error('Percentages must sum to 100%');
                }
            }
        }

        const session = await mongoose.startSession();
        let response: ExpenseResponse;

        try {
            await session.withTransaction(async () => {
                const expense = await Expense.create([{
                    groupId,
                    title: data.title,
                    amountTotal: data.amountTotal,
                    currency: data.currency || 'VND',
                    splitType: data.splitType,
                    category: data.category,
                    expenseType: data.expenseType,
                    paidBy: userId,
                    expenseDate: data.expenseDate || new Date(),
                    note: data.note
                }], { session }).then(res => res[0]);

                await ExpenseShare.insertMany(
                    calculatedShares.map(s => ({
                        expenseId: expense._id.toString(),
                        userId: s.userId,
                        owedAmount: s.owedAmount
                    })), { session }
                );

                if (itemsToCreate.length > 0) {
                    await ExpenseItem.insertMany(
                        itemsToCreate.map(item => ({
                            expenseId: expense._id.toString(),
                            ...item
                        })), { session }
                    );
                }

                // Ledger entries inside same session
                const { ledgerService } = await import('./ledgerService');
                const { LedgerType } = await import('../models/Ledger');

                const ledgerEntries = [];

                ledgerEntries.push({
                    groupId,
                    userId: userId,
                    amount: data.amountTotal,
                    type: LedgerType.EXPENSE_PAID,
                    referenceId: expense._id.toString(),
                    referenceType: 'EXPENSE',
                    description: `Paid for: ${data.title}`
                });

                for (const share of calculatedShares) {
                    ledgerEntries.push({
                        groupId,
                        userId: share.userId,
                        amount: -share.owedAmount,
                        type: LedgerType.EXPENSE_SHARE,
                        referenceId: expense._id.toString(),
                        referenceType: 'EXPENSE',
                        description: `Share of: ${data.title}`
                    });
                }

                await ledgerService.createEntries(ledgerEntries, session);
                await ledgerService.updateGroupBalances(groupId, session);

                // Fetch complete expense with relations (same session)
                const [paidByUser, shares, items] = await Promise.all([
                    User.findById(userId).select('_id email displayName avatarUrl').session(session),
                    ExpenseShare.find({ expenseId: expense._id.toString() }).session(session),
                    ExpenseItem.find({ expenseId: expense._id.toString() }).session(session)
                ]);

                const shareUsers = await User.find({
                    _id: { $in: shares.map(s => s.userId) }
                }).select('_id email displayName avatarUrl').session(session);

                const itemUsers = await User.find({
                    _id: { $in: items.map(i => i.assignedTo) }
                }).select('_id email displayName avatarUrl').session(session);

                const userMap = new Map();
                [...shareUsers, ...itemUsers].forEach(u => userMap.set(u._id.toString(), u));

                response = {
                    id: expense._id.toString(),
                    groupId: expense.groupId,
                    title: expense.title,
                    amountTotal: Number(expense.amountTotal),
                    currency: expense.currency,
                    splitType: expense.splitType,
                    category: expense.category ?? undefined,
                    expenseType: expense.expenseType ?? undefined,
                    paidBy: transformUser(paidByUser!),
                    expenseDate: expense.expenseDate,
                    note: expense.note ?? undefined,
                    shares: shares.map(s => ({
                        id: s._id.toString(),
                        expenseId: s.expenseId,
                        userId: s.userId,
                        owedAmount: Number(s.owedAmount),
                        shareNote: s.shareNote ?? undefined,
                        user: transformUser(userMap.get(s.userId))
                    })),
                    items: items.map(item => ({
                        id: item._id.toString(),
                        expenseId: item.expenseId,
                        name: item.name,
                        price: Number(item.price),
                        quantity: item.quantity,
                        assignedTo: item.assignedTo,
                        user: transformUser(userMap.get(item.assignedTo))
                    })),
                    createdAt: expense.createdAt
                };
            });
        } finally {
            await session.endSession();
        }

        // Send notifications to all members who have a share in the expense (after transaction completes)
        const payer = await User.findById(userId);
        const payerName = payer?.displayName || 'Someone';
        
        for (const share of calculatedShares) {
            if (share.userId !== userId) { // Don't notify the payer
                await notificationService.createNotification({
                    userId: share.userId,
                    type: NotificationType.EXPENSE_CREATED,
                    title: 'New Expense',
                    message: `${payerName} added an expense: ${data.title} - You owe ${share.owedAmount.toLocaleString()} ${data.currency || 'VND'}`,
                    data: {
                        expenseId: response!.id,
                        groupId,
                        title: data.title,
                        owedAmount: share.owedAmount
                    }
                });
            }
        }

        return response!;
    },

    async getExpenseById(userId: string, groupId: string, expenseId: string): Promise<ExpenseResponse> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        const expense = await Expense.findOne({ _id: expenseId, groupId });

        if (!expense) {
            throw new Error('Expense not found');
        }

        const [paidByUser, shares] = await Promise.all([
            User.findById(expense.paidBy).select('_id email displayName avatarUrl'),
            ExpenseShare.find({ expenseId: expense._id.toString() })
        ]);

        const shareUsers = await User.find({
            _id: { $in: shares.map(s => s.userId) }
        }).select('_id email displayName avatarUrl');

        const userMap = new Map();
        shareUsers.forEach(u => userMap.set(u._id.toString(), u));

        return {
            id: expense._id.toString(),
            groupId: expense.groupId,
            title: expense.title,
            amountTotal: Number(expense.amountTotal),
            currency: expense.currency,
            splitType: expense.splitType,
            category: expense.category ?? undefined,
            expenseType: expense.expenseType ?? undefined,
            paidBy: transformUser(paidByUser!),
            expenseDate: expense.expenseDate,
            note: expense.note ?? undefined,
            shares: shares.map(s => ({
                id: s._id.toString(),
                expenseId: s.expenseId,
                userId: s.userId,
                owedAmount: Number(s.owedAmount),
                shareNote: s.shareNote ?? undefined,
                user: transformUser(userMap.get(s.userId))
            })),
            createdAt: expense.createdAt
        };
    },

    async getExpensesByGroup(userId: string, groupId: string, page: number = 1, limit: number = 20): Promise<{ expenses: ExpenseResponse[]; total: number }> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        const [expenses, total] = await Promise.all([
            Expense.find({ groupId })
                .sort({ expenseDate: -1 })
                .skip((page - 1) * limit)
                .limit(limit),
            Expense.countDocuments({ groupId })
        ]);

        const expenseResponses = await Promise.all(
            expenses.map(async (expense) => {
                const [paidByUser, shares] = await Promise.all([
                    User.findById(expense.paidBy).select('_id email displayName avatarUrl'),
                    ExpenseShare.find({ expenseId: expense._id.toString() })
                ]);

                const shareUsers = await User.find({
                    _id: { $in: shares.map(s => s.userId) }
                }).select('_id email displayName avatarUrl');

                const userMap = new Map();
                shareUsers.forEach(u => userMap.set(u._id.toString(), u));

                return {
                    id: expense._id.toString(),
                    groupId: expense.groupId,
                    title: expense.title,
                    amountTotal: Number(expense.amountTotal),
                    currency: expense.currency,
                    splitType: expense.splitType,
                    category: expense.category ?? undefined,
                    expenseType: expense.expenseType ?? undefined,
                    paidBy: transformUser(paidByUser!),
                    expenseDate: expense.expenseDate,
                    note: expense.note ?? undefined,
                    shares: shares.map(s => ({
                        id: s._id.toString(),
                        expenseId: s.expenseId,
                        userId: s.userId,
                        owedAmount: Number(s.owedAmount),
                        shareNote: s.shareNote ?? undefined,
                        user: transformUser(userMap.get(s.userId))
                    })),
                    createdAt: expense.createdAt
                };
            })
        );

        return {
            expenses: expenseResponses,
            total
        };
    },

    async updateExpense(userId: string, groupId: string, expenseId: string, data: UpdateExpenseRequest): Promise<ExpenseResponse> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        const existingExpense = await Expense.findOne({ _id: expenseId, groupId });

        if (!existingExpense) {
            throw new Error('Expense not found');
        }

        if (existingExpense.paidBy !== userId && membership.role !== 'OWNER' && membership.role !== 'ADMIN') {
            throw new Error('Only the payer or group admin can update this expense');
        }

        if (data.shares && data.splitType) {
            const calculatedShares = calculateShares(
                data.amountTotal || Number(existingExpense.amountTotal),
                data.splitType,
                data.shares
            );

            await ExpenseShare.deleteMany({ expenseId });
            await ExpenseShare.insertMany(
                calculatedShares.map(s => ({
                    expenseId,
                    userId: s.userId,
                    owedAmount: s.owedAmount
                }))
            );
        }

        await Expense.findByIdAndUpdate(expenseId, {
            title: data.title,
            amountTotal: data.amountTotal,
            currency: data.currency,
            category: data.category,
            expenseType: data.expenseType,
            expenseDate: data.expenseDate,
            note: data.note
        });

        return this.getExpenseById(userId, groupId, expenseId);
    },

    async deleteExpense(userId: string, groupId: string, expenseId: string): Promise<void> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        const expense = await Expense.findOne({ _id: expenseId, groupId });

        if (!expense) {
            throw new Error('Expense not found');
        }

        if (expense.paidBy !== userId && membership.role !== 'OWNER' && membership.role !== 'ADMIN') {
            throw new Error('Only the payer or group admin can delete this expense');
        }

        await Promise.all([
            Expense.findByIdAndDelete(expenseId),
            ExpenseShare.deleteMany({ expenseId }),
            ExpenseItem.deleteMany({ expenseId })
        ]);
    }
};
