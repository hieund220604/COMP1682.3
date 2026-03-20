import { Transaction } from '../models/Transaction';
import { GroupMember } from '../models/GroupMember';
import {
    CreateTransactionRequest,
    TransactionResponse,
    TransactionType
} from '../type/transaction';

function transformTransaction(transaction: any): TransactionResponse {
    return {
        id: transaction._id.toString(),
        userId: transaction.userId,
        groupId: transaction.groupId ?? undefined,
        type: transaction.type as TransactionType,
        amount: Number(transaction.amount),
        balanceBefore: Number(transaction.balanceBefore),
        balanceAfter: Number(transaction.balanceAfter),
        currency: transaction.currency,
        description: transaction.description ?? undefined,
        referenceId: transaction.referenceId ?? undefined,
        referenceType: transaction.referenceType ?? undefined,
        createdAt: transaction.createdAt
    };
}

export const transactionService = {
    /**
     * Create a new transaction record
     */
    async createTransaction(data: CreateTransactionRequest): Promise<TransactionResponse> {
        const payload = {
            userId: data.userId,
            groupId: data.groupId,
            type: data.type,
            amount: data.amount,
            balanceBefore: data.balanceBefore,
            balanceAfter: data.balanceAfter,
            currency: data.currency || 'VND',
            description: data.description,
            referenceId: data.referenceId,
            referenceType: data.referenceType
        };

        const [transaction] = data.session
            ? await Transaction.create([payload], { session: data.session })
            : await Transaction.create([payload]);

        return transformTransaction(transaction);
    },

    /**
     * Get all transactions for a user
     */
    async getTransactionsByUser(
        userId: string,
        options: {
            page?: number;
            limit?: number;
            type?: TransactionType;
        } = {}
    ): Promise<{ transactions: TransactionResponse[]; total: number }> {
        const page = options.page || 1;
        const limit = options.limit || 20;

        const where: any = { userId };
        if (options.type) {
            where.type = options.type;
        }

        const [transactions, total] = await Promise.all([
            Transaction.find(where)
                .sort({ createdAt: -1 })
                .skip((page - 1) * limit)
                .limit(limit),
            Transaction.countDocuments(where)
        ]);

        return {
            transactions: transactions.map(transformTransaction),
            total
        };
    },

    /**
     * Get all transactions for a specific group
     */
    async getTransactionsByGroup(
        userId: string,
        groupId: string,
        options: {
            page?: number;
            limit?: number;
            type?: TransactionType;
        } = {}
    ): Promise<{ transactions: TransactionResponse[]; total: number }> {
        // Verify user is a member of the group
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        const page = options.page || 1;
        const limit = options.limit || 20;

        const where: any = { groupId };
        if (options.type) {
            where.type = options.type;
        }

        const [transactions, total] = await Promise.all([
            Transaction.find(where)
                .sort({ createdAt: -1 })
                .skip((page - 1) * limit)
                .limit(limit),
            Transaction.countDocuments(where)
        ]);

        return {
            transactions: transactions.map(transformTransaction),
            total
        };
    },

    /**
     * Get a single transaction by ID
     */
    async getTransactionById(transactionId: string, userId: string): Promise<TransactionResponse | null> {
        const transaction = await Transaction.findById(transactionId);

        if (!transaction) {
            return null;
        }

        // Only allow user to see their own transactions
        if (transaction.userId !== userId) {
            throw new Error('Permission denied');
        }

        return transformTransaction(transaction);
    },

    /**
     * Get user's balance summary from transactions
     */
    async getUserTransactionSummary(userId: string): Promise<{
        totalTopUp: number;
        totalWithdrawal: number;
        totalSent: number;
        totalReceived: number;
        transactionCount: number;
    }> {
        const transactions = await Transaction.find({ userId }).select('type amount');

        let totalTopUp = 0;
        let totalWithdrawal = 0;
        let totalSent = 0;
        let totalReceived = 0;

        transactions.forEach((t: any) => {
            const amount = Number(t.amount);
            switch (t.type) {
                case TransactionType.TOP_UP:
                case TransactionType.REFUND:
                    totalTopUp += amount;
                    break;
                case TransactionType.WITHDRAWAL:
                case TransactionType.SUBSCRIPTION_FEE:
                    totalWithdrawal += amount;
                    break;
                case TransactionType.TRANSFER_SENT:
                    totalSent += amount;
                    break;
                case TransactionType.TRANSFER_RECEIVED:
                    totalReceived += amount;
                    break;
            }
        });

        return {
            totalTopUp,
            totalWithdrawal,
            totalSent,
            totalReceived,
            transactionCount: transactions.length
        };
    }
};
