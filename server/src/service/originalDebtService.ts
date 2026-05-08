import { OriginalDebt } from '../models/OriginalDebt';
import { Invoice } from '../models/Invoice';
import { User } from '../models/User';
import { GroupMember } from '../models/GroupMember';
import { Group } from '../models/Group';
import { Transfer } from '../models/Transfer';
import { TransferDebtAllocation } from '../models/TransferDebtAllocation';
import { UserSummary, UserDebtBreakdown, NetBalanceResponse } from '../type/invoice';
import mongoose from 'mongoose';

const transformUser = (user: any): UserSummary => ({
    id: user._id.toString(),
    displayName: user.displayName,
    avatarUrl: user.avatarUrl
});

export const originalDebtService = {
    /**
     * Filter out debts whose ALL associated transfers were cancelled
     * without ever being completed (paidAt is null).
     * Debts with no allocations are kept (no transfer was ever created for them).
     */
    async filterCancelledTransferDebts(debts: any[]): Promise<any[]> {
        if (debts.length === 0) return debts;

        const debtIds = debts.map(d => d._id.toString());

        // Get all allocations for these debts
        const allAllocations = await TransferDebtAllocation.find({
            originalDebtId: { $in: debtIds }
        });

        if (allAllocations.length === 0) return debts;

        // Get all referenced transfers to check their status
        const transferIds = [...new Set(allAllocations.map(a => a.transferId))];
        const allTransfers = await Transfer.find({ _id: { $in: transferIds } });
        const transferMap = new Map(allTransfers.map(t => [t._id.toString(), t]));

        // Group allocations by debtId
        const allocsByDebt = new Map<string, string[]>();
        for (const alloc of allAllocations) {
            const tids = allocsByDebt.get(alloc.originalDebtId) || [];
            tids.push(alloc.transferId);
            allocsByDebt.set(alloc.originalDebtId, tids);
        }

        // Get invoice IDs to check their status
        const invoiceIds = [...new Set(debts.map(d => d.invoiceId))];
        const invoices = await Invoice.find({ _id: { $in: invoiceIds } });
        const invoiceMap = new Map(invoices.map(inv => [inv._id.toString(), inv]));

        // Find debts where ALL associated transfers are CANCELLED and were never paid
        // BUT only exclude if the invoice is NOT in SUBMITTED status
        // (SUBMITTED means it's available for a new payment request)
        const debtsToExclude = new Set<string>();
        for (const [debtId, tids] of allocsByDebt) {
            const allCancelledNeverPaid = tids.every(tid => {
                const t = transferMap.get(tid);
                return t && t.status === 'CANCELLED' && !t.paidAt;
            });
            if (allCancelledNeverPaid) {
                // Check if the invoice is back to SUBMITTED - if so, keep the debt
                const debt = debts.find(d => d._id.toString() === debtId);
                if (debt) {
                    const invoice = invoiceMap.get(debt.invoiceId);
                    // Only exclude if invoice is NOT in a re-usable state
                    if (invoice && invoice.status !== 'SUBMITTED' && invoice.status !== 'LOCKED') {
                        debtsToExclude.add(debtId);
                    }
                    // If invoice is SUBMITTED or LOCKED, keep the debt (it will be part of next payment request)
                }
            }
        }

        if (debtsToExclude.size === 0) return debts;

        return debts.filter(d => !debtsToExclude.has(d._id.toString()));
    },

    /**
     * Get remaining debts for a group
     */
    async getRemainingDebts(groupId: string): Promise<any[]> {
        const debts = await OriginalDebt.find({
            groupId,
            remainingAmount: { $gt: 0.01 }
        });

        return debts.map(d => ({
            id: d._id.toString(),
            groupId: d.groupId,
            invoiceId: d.invoiceId,
            debtorId: d.debtorId,
            creditorId: d.creditorId,
            originalAmount: d.originalAmount,
            remainingAmount: d.remainingAmount,
            createdAt: d.createdAt
        }));
    },

    /**
     * Get net balance for all users in a group
     * Positive = owed to them (they should receive)
     * Negative = they owe (they should pay)
     */
    async getNetBalances(groupId: string): Promise<Map<string, number>> {
        const debts = await OriginalDebt.find({
            groupId,
            remainingAmount: { $gt: 0.01 }
        });

        // Filter out debts whose ALL transfers were cancelled without ever being paid
        const filteredDebts = await this.filterCancelledTransferDebts(debts);

        const balanceMap = new Map<string, number>();

        for (const debt of filteredDebts) {
            // Debtor has negative balance (owes money)
            const debtorBalance = balanceMap.get(debt.debtorId) || 0;
            balanceMap.set(debt.debtorId, debtorBalance - debt.remainingAmount);

            // Creditor has positive balance (is owed money)
            const creditorBalance = balanceMap.get(debt.creditorId) || 0;
            balanceMap.set(debt.creditorId, creditorBalance + debt.remainingAmount);
        }

        return balanceMap;
    },

    /**
     * Get net balance for a specific user
     */
    async getUserNetBalance(groupId: string, userId: string): Promise<NetBalanceResponse> {
        let debts = await OriginalDebt.find({
            groupId,
            remainingAmount: { $gt: 0.01 },
            $or: [{ debtorId: userId }, { creditorId: userId }]
        });

        // Filter out debts whose ALL transfers were cancelled without ever being paid
        debts = await this.filterCancelledTransferDebts(debts);

        // Batch-load all referenced invoices and users (eliminates N+1 queries)
        const invoiceIds = [...new Set(debts.map(d => d.invoiceId))];
        const creditorIds = [...new Set(debts.filter(d => d.debtorId === userId).map(d => d.creditorId))];

        const [invoices, creditors] = await Promise.all([
            Invoice.find({ _id: { $in: invoiceIds } }),
            User.find({ _id: { $in: creditorIds } })
        ]);

        const invoiceMap = new Map(invoices.map(inv => [inv._id.toString(), inv]));
        const creditorMap = new Map(creditors.map(u => [u._id.toString(), u]));

        let netBalance = 0;
        const breakdown: UserDebtBreakdown[] = [];

        for (const debt of debts) {
            if (debt.debtorId === userId) {
                // User owes this amount
                netBalance -= debt.remainingAmount;
                const invoice = invoiceMap.get(debt.invoiceId);
                const creditor = creditorMap.get(debt.creditorId);
                breakdown.push({
                    invoiceId: debt.invoiceId,
                    invoiceTitle: invoice?.title || 'Unknown',
                    creditor: creditor ? transformUser(creditor) : { id: debt.creditorId, displayName: null, avatarUrl: null },
                    originalAmount: debt.originalAmount,
                    remainingAmount: debt.remainingAmount,
                    // Exchange rate lock info
                    originalCurrency: debt.originalCurrency ?? undefined,
                    originalAmountInCurrency: debt.originalAmountInCurrency ?? undefined,
                    exchangeRateUsed: debt.exchangeRateUsed ?? undefined
                });
            } else if (debt.creditorId === userId) {
                // User is owed this amount
                netBalance += debt.remainingAmount;
            }
        }

        return {
            userId,
            netBalance: Math.round(netBalance * 100) / 100,
            breakdown
        };
    },

    /**
     * Reduce debt when transfer is completed
     * Returns true if successful
     */
    async reduceDebt(
        originalDebtId: string,
        amount: number,
        session?: mongoose.ClientSession
    ): Promise<boolean> {
        const debt = await OriginalDebt.findById(originalDebtId);
        if (!debt) {
            throw new Error('Original debt not found');
        }

        if (debt.remainingAmount < amount - 0.01) {
            throw new Error('Amount exceeds remaining debt');
        }

        const newRemaining = Math.max(0, debt.remainingAmount - amount);

        if (session) {
            await OriginalDebt.findByIdAndUpdate(
                originalDebtId,
                { remainingAmount: Math.round(newRemaining * 100) / 100 },
                { session }
            );
        } else {
            await OriginalDebt.findByIdAndUpdate(
                originalDebtId,
                { remainingAmount: Math.round(newRemaining * 100) / 100 }
            );
        }

        return true;
    },

    /**
     * Restore debt when a completed transfer is refunded (cancel mid-way)
     * This increases the remainingAmount back, capped at originalAmount
     */
    async restoreDebt(
        originalDebtId: string,
        amount: number,
        session?: mongoose.ClientSession
    ): Promise<boolean> {
        const debt = await OriginalDebt.findById(originalDebtId);
        if (!debt) {
            throw new Error('Original debt not found');
        }

        const newRemaining = Math.min(debt.originalAmount, debt.remainingAmount + amount);

        const updateOpts = session ? { session } : {};
        await OriginalDebt.findByIdAndUpdate(
            originalDebtId,
            { remainingAmount: Math.round(newRemaining * 100) / 100 },
            updateOpts
        );

        return true;
    },

    /**
     * Get debts between two users in a group
     */
    async getDebtsBetweenUsers(
        groupId: string,
        debtorId: string,
        creditorId: string
    ): Promise<any[]> {
        const debts = await OriginalDebt.find({
            groupId,
            debtorId,
            creditorId,
            remainingAmount: { $gt: 0.01 }
        }).sort({ createdAt: 1 }); // Oldest first (FIFO)

        return debts.map(d => ({
            id: d._id.toString(),
            invoiceId: d.invoiceId,
            originalAmount: d.originalAmount,
            remainingAmount: d.remainingAmount
        }));
    },

    /**
     * Check if user can leave group (net balance must be 0)
     */
    async canUserLeaveGroup(groupId: string, userId: string): Promise<{ canLeave: boolean; reason?: string }> {
        const balance = await this.getUserNetBalance(groupId, userId);

        if (Math.abs(balance.netBalance) > 0.01) {
            if (balance.netBalance < 0) {
                return {
                    canLeave: false,
                    reason: `You still owe ${Math.abs(balance.netBalance).toLocaleString()} VND in this group`
                };
            } else {
                return {
                    canLeave: false,
                    reason: `You are still owed ${balance.netBalance.toLocaleString()} VND in this group`
                };
            }
        }

        return { canLeave: true };
    },

    /**
     * Get user's debts in a specific group (OriginalDebt-based calculation)
     * Returns who the user owes and who owes the user in this group
     */
    async getUserDebtsInGroup(userId: string, groupId: string): Promise<{
        groupId: string;
        currency: string;
        iOwe: Array<{ userId: string; displayName?: string; avatarUrl?: string; amount: number }>;
        oweMe: Array<{ userId: string; displayName?: string; avatarUrl?: string; amount: number }>;
        netBalance: number;
    }> {
        // Verify membership
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) {
            throw new Error('You are not a member of this group');
        }

        // Get group for currency
        const group = await Group.findById(groupId);
        if (!group) {
            throw new Error('Group not found');
        }

        // Get all debts in this group where user is involved
        let debts = await OriginalDebt.find({
            groupId,
            remainingAmount: { $gt: 0.01 },
            $or: [{ debtorId: userId }, { creditorId: userId }]
        });

        // Filter out debts whose ALL transfers were cancelled without ever being paid
        debts = await this.filterCancelledTransferDebts(debts);

        // Track net amount per other user
        const netAmountMap = new Map<string, number>();

        for (const debt of debts) {
            if (debt.debtorId === userId) {
                // User owes money to creditor
                const current = netAmountMap.get(debt.creditorId) || 0;
                netAmountMap.set(debt.creditorId, current - debt.remainingAmount);
            } else if (debt.creditorId === userId) {
                // User is owed money by debtor
                const current = netAmountMap.get(debt.debtorId) || 0;
                netAmountMap.set(debt.debtorId, current + debt.remainingAmount);
            }
        }

        // Get user info for all involved users
        const otherUserIds = Array.from(netAmountMap.keys());
        const users = await User.find({ _id: { $in: otherUserIds } }).select('_id displayName avatarUrl');
        const userMap = new Map(users.map(u => [u._id.toString(), u]));

        // Build response arrays
        const iOwe: any[] = [];
        const oweMe: any[] = [];
        let netBalance = 0;

        for (const [otherUserId, netAmount] of netAmountMap.entries()) {
            if (netAmount > 0.01) {
                // Others owe me
                const user = userMap.get(otherUserId);
                oweMe.push({
                    userId: otherUserId,
                    displayName: user?.displayName,
                    avatarUrl: user?.avatarUrl,
                    amount: Math.round(netAmount * 100) / 100
                });
                netBalance += netAmount;
            } else if (netAmount < -0.01) {
                // I owe others
                const user = userMap.get(otherUserId);
                iOwe.push({
                    userId: otherUserId,
                    displayName: user?.displayName,
                    avatarUrl: user?.avatarUrl,
                    amount: Math.round(Math.abs(netAmount) * 100) / 100
                });
                netBalance += netAmount;
            }
        }

        return {
            groupId,
            currency: group.baseCurrency || 'VND',
            iOwe,
            oweMe,
            netBalance: Math.round(netBalance * 100) / 100
        };
    },

    /**
     * Fallback mechanism to reduce original debts between two users by a specific amount (FIFO)
     */
    async reduceDebtsBetweenUsers(groupId: string, debtorId: string, creditorId: string, amount: number, session?: any): Promise<void> {
        let remainingToReduce = amount;

        const query = OriginalDebt.find({
            groupId,
            debtorId,
            creditorId,
            remainingAmount: { $gt: 0.01 }
        }).sort({ createdAt: 1 });

        const debts = session ? await query.session(session) : await query;

        for (const debt of debts) {
            if (remainingToReduce <= 0.01) break;

            const reduction = Math.min(debt.remainingAmount, remainingToReduce);
            debt.remainingAmount -= reduction;

            if (debt.remainingAmount < 0.01) {
                debt.remainingAmount = 0;
            }

            if (session) {
                await debt.save({ session });
            } else {
                await debt.save();
            }
            remainingToReduce -= reduction;
        }

        if (remainingToReduce > 0.01) {
            console.warn(`[WARNING] Could not fully reduce debt between ${debtorId} and ${creditorId}. Remaining unwiped amount: ${remainingToReduce}`);
        }
    },

    async getUserGlobalDebtSummary(userId: string): Promise<{
        totalI_Owe: number;
        totalOwe_Me: number;
        netBalance: number;
    }> {
        // Get all groups where user is an active member
        const memberships = await GroupMember.find({ userId, leftAt: null });
        const groupIds = memberships.map(m => m.groupId);

        if (groupIds.length === 0) {
            return {
                totalI_Owe: 0,
                totalOwe_Me: 0,
                netBalance: 0
            };
        }

        // Use OriginalDebts for accurate calculation (not PENDING transfers)
        let debts = await OriginalDebt.find({
            groupId: { $in: groupIds },
            remainingAmount: { $gt: 0.01 },
            $or: [{ debtorId: userId }, { creditorId: userId }]
        });

        // Filter out debts whose ALL transfers were cancelled without ever being paid
        debts = await this.filterCancelledTransferDebts(debts);

        let totalIOwe = 0;
        let totalOweMe = 0;

        for (const debt of debts) {
            if (debt.debtorId === userId) {
                // User owes this amount
                totalIOwe += debt.remainingAmount;
            } else if (debt.creditorId === userId) {
                // User is owed this amount
                totalOweMe += debt.remainingAmount;
            }
        }

        return {
            totalI_Owe: Math.round(totalIOwe * 100) / 100,
            totalOwe_Me: Math.round(totalOweMe * 100) / 100,
            netBalance: Math.round((totalOweMe - totalIOwe) * 100) / 100
        };
    }
};
