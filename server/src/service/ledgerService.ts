import { Ledger, LedgerType } from '../models/Ledger';
import { GroupMemberBalance } from '../models/GroupMemberBalance';
import mongoose from 'mongoose';
import { ClientSession } from 'mongoose';

export interface LedgerEntry {
    groupId: string;
    userId: string;
    amount: number;
    type: LedgerType;
    referenceId: string;
    referenceType: string;
    description: string;
}

export interface BalanceMap {
    [userId: string]: number;
}

export const ledgerService = {
    /**
     * Create a single ledger entry
     */
    async createEntry(entry: LedgerEntry, session?: ClientSession): Promise<void> {
        if (session) {
            await Ledger.create([entry], { session });
        } else {
            await Ledger.create(entry);
        }
    },

    /**
     * Create multiple ledger entries in a transaction
     */
    async createEntries(entries: LedgerEntry[], session?: ClientSession): Promise<void> {
        if (entries.length === 0) return;

        if (session) {
            await Ledger.insertMany(entries, { session });
            return;
        }

        const localSession = await mongoose.startSession();
        await localSession.withTransaction(async () => {
            await Ledger.insertMany(entries, { session: localSession });
        });
        localSession.endSession();
    },

    /**
     * Get net balance for a specific user in a group
     */
    async getNetBalance(groupId: string, userId: string): Promise<number> {
        const entries = await Ledger.find({ groupId, userId });
        return entries.reduce((sum, entry) => sum + Number(entry.amount), 0);
    },

    /**
     * Get all member balances in a group
     */
    async getGroupBalances(groupId: string): Promise<BalanceMap> {
        const balances = await GroupMemberBalance.find({ groupId });

        const balanceMap: BalanceMap = {};
        balances.forEach(b => {
            balanceMap[b.userId] = Number(b.netBalance);
        });

        return balanceMap;
    },

    /**
     * Recalculate and update all balances for a group
     * Call this after creating expenses or payments
     */
    async updateGroupBalances(groupId: string, session?: ClientSession): Promise<void> {
        const entries = session
            ? await Ledger.find({ groupId }).session(session)
            : await Ledger.find({ groupId });

        // Calculate net balance per user
        const balances: BalanceMap = {};
        entries.forEach(entry => {
            if (!balances[entry.userId]) {
                balances[entry.userId] = 0;
            }
            balances[entry.userId] += Number(entry.amount);
        });

        // Update or create balance records
        if (session) {
            for (const [userId, netBalance] of Object.entries(balances)) {
                await GroupMemberBalance.findOneAndUpdate(
                    { groupId, userId },
                    {
                        netBalance,
                        lastUpdated: new Date()
                    },
                    {
                        upsert: true,
                        session
                    }
                );
            }
            return;
        }

        const localSession = await mongoose.startSession();
        await localSession.withTransaction(async () => {
            for (const [userId, netBalance] of Object.entries(balances)) {
                await GroupMemberBalance.findOneAndUpdate(
                    { groupId, userId },
                    {
                        netBalance,
                        lastUpdated: new Date()
                    },
                    {
                        upsert: true,
                        session: localSession
                    }
                );
            }
        });
        localSession.endSession();
    },

    /**
     * Get ledger history for a user in a group
     */
    async getUserLedger(groupId: string, userId: string, limit: number = 50): Promise<any[]> {
        const entries = await Ledger.find({ groupId, userId })
            .sort({ createdAt: -1 })
            .limit(limit);

        return entries.map(e => ({
            id: e._id.toString(),
            amount: Number(e.amount),
            type: e.type,
            description: e.description,
            referenceId: e.referenceId,
            referenceType: e.referenceType,
            createdAt: e.createdAt
        }));
    },

    /**
     * Get group ledger history
     */
    async getGroupLedger(groupId: string, limit: number = 100): Promise<any[]> {
        const entries = await Ledger.find({ groupId })
            .sort({ createdAt: -1 })
            .limit(limit);

        return entries.map(e => ({
            id: e._id.toString(),
            userId: e.userId,
            amount: Number(e.amount),
            type: e.type,
            description: e.description,
            referenceId: e.referenceId,
            referenceType: e.referenceType,
            createdAt: e.createdAt
        }));
    }
};
