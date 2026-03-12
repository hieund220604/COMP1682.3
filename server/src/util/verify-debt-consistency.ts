/**
 * Verification script to compare Expense-based vs OriginalDebt-based debt calculations
 * Run this before deploying to identify any discrepancies between the two systems
 * 
 * Usage: npx ts-node src/util/verify-debt-consistency.ts
 */

import mongoose from 'mongoose';
import { GroupMember } from '../models/GroupMember';
import { Group } from '../models/Group';
import { User } from '../models/User';
import { Expense } from '../models/Expense';
import { ExpenseShare } from '../models/ExpenseShare';
import { Settlement } from '../models/Settlement';
import { OriginalDebt } from '../models/OriginalDebt';

interface DiscrepancyReport {
    groupId: string;
    groupName: string;
    userId: string;
    userName: string;
    oldCalculation: {
        iOwe: number;
        oweMe: number;
        netBalance: number;
    };
    newCalculation: {
        iOwe: number;
        oweMe: number;
        netBalance: number;
    };
    difference: number;
}

/**
 * Old Expense-based calculation (from settlementService.getUserDebts)
 */
async function calculateDebtsExpenseBased(userId: string, groupId: string): Promise<{
    iOwe: number;
    oweMe: number;
    netBalance: number;
}> {
    const members = await GroupMember.find({ groupId, leftAt: null });
    const expenses = await Expense.find({ groupId });
    const expenseIds = expenses.map(e => e._id.toString());
    const shares = await ExpenseShare.find({ expenseId: { $in: expenseIds } });
    const settlements = await Settlement.find({ groupId, status: 'COMPLETED' });

    const debt = new Map<string, Map<string, number>>();
    members.forEach(m => debt.set(m.userId, new Map()));

    // Calculate debts from expenses
    expenses.forEach(expense => {
        const expenseShares = shares.filter(s => s.expenseId === expense._id.toString());
        expenseShares.forEach(share => {
            if (share.userId !== expense.paidBy) {
                const currentDebt = debt.get(share.userId)?.get(expense.paidBy) || 0;
                debt.get(share.userId)?.set(expense.paidBy, currentDebt + Number(share.owedAmount));
            }
        });
    });

    // Subtract settlements
    settlements.forEach(s => {
        const currentDebt = debt.get(s.fromUserId)?.get(s.toUserId) || 0;
        debt.get(s.fromUserId)?.set(s.toUserId, currentDebt - Number(s.amount));
    });

    let iOweTotal = 0;
    let oweMeTotal = 0;
    let netBalance = 0;

    members.forEach(m => {
        if (m.userId === userId) return;

        const iOweToThem = debt.get(userId)?.get(m.userId) || 0;
        const theyOweToMe = debt.get(m.userId)?.get(userId) || 0;
        const netAmount = theyOweToMe - iOweToThem;

        if (netAmount > 0.01) {
            oweMeTotal += netAmount;
            netBalance += netAmount;
        } else if (netAmount < -0.01) {
            iOweTotal += Math.abs(netAmount);
            netBalance += netAmount;
        }
    });

    return {
        iOwe: Math.round(iOweTotal * 100) / 100,
        oweMe: Math.round(oweMeTotal * 100) / 100,
        netBalance: Math.round(netBalance * 100) / 100
    };
}

/**
 * New OriginalDebt-based calculation
 */
async function calculateDebtsOriginalDebtBased(userId: string, groupId: string): Promise<{
    iOwe: number;
    oweMe: number;
    netBalance: number;
}> {
    const debts = await OriginalDebt.find({
        groupId,
        remainingAmount: { $gt: 0.01 },
        $or: [{ debtorId: userId }, { creditorId: userId }]
    });

    const netAmountMap = new Map<string, number>();

    for (const debt of debts) {
        if (debt.debtorId === userId) {
            const current = netAmountMap.get(debt.creditorId) || 0;
            netAmountMap.set(debt.creditorId, current - debt.remainingAmount);
        } else if (debt.creditorId === userId) {
            const current = netAmountMap.get(debt.debtorId) || 0;
            netAmountMap.set(debt.debtorId, current + debt.remainingAmount);
        }
    }

    let iOweTotal = 0;
    let oweMeTotal = 0;
    let netBalance = 0;

    for (const [, netAmount] of netAmountMap) {
        if (netAmount > 0.01) {
            oweMeTotal += netAmount;
            netBalance += netAmount;
        } else if (netAmount < -0.01) {
            iOweTotal += Math.abs(netAmount);
            netBalance += netAmount;
        }
    }

    return {
        iOwe: Math.round(iOweTotal * 100) / 100,
        oweMe: Math.round(oweMeTotal * 100) / 100,
        netBalance: Math.round(netBalance * 100) / 100
    };
}

/**
 * Main verification function
 */
async function verifyDebtConsistency(maxGroups: number = 50): Promise<void> {
    try {
        // Connect to database
        const mongoUri = process.env.MONGO_URI || 'mongodb://localhost:27017/splitpal';
        await mongoose.connect(mongoUri);
        console.log('✅ Connected to MongoDB');

        // Get sample of groups
        const groups = await Group.find().limit(maxGroups);
        console.log(`\n📊 Analyzing ${groups.length} groups...\n`);

        const discrepancies: DiscrepancyReport[] = [];
        let totalComparisons = 0;
        let matchingCalculations = 0;

        for (const group of groups) {
            const members = await GroupMember.find({ groupId: group._id.toString(), leftAt: null });

            for (const member of members) {
                totalComparisons++;

                const oldCalc = await calculateDebtsExpenseBased(member.userId, group._id.toString());
                const newCalc = await calculateDebtsOriginalDebtBased(member.userId, group._id.toString());

                const difference = Math.abs(oldCalc.netBalance - newCalc.netBalance);

                if (difference > 0.02) {
                    // Significant discrepancy found
                    const user = await User.findById(member.userId).select('displayName');

                    discrepancies.push({
                        groupId: group._id.toString(),
                        groupName: group.name,
                        userId: member.userId,
                        userName: user?.displayName || 'Unknown',
                        oldCalculation: oldCalc,
                        newCalculation: newCalc,
                        difference
                    });
                } else {
                    matchingCalculations++;
                }
            }
        }

        // Print summary
        console.log('=' .repeat(80));
        console.log('VERIFICATION SUMMARY');
        console.log('=' .repeat(80));
        console.log(`Total comparisons: ${totalComparisons}`);
        console.log(`Matching calculations: ${matchingCalculations} (${(matchingCalculations / totalComparisons * 100).toFixed(1)}%)`);
        console.log(`Discrepancies found: ${discrepancies.length} (${(discrepancies.length / totalComparisons * 100).toFixed(1)}%)`);

        if (discrepancies.length > 0) {
            console.log('\n⚠️  DISCREPANCIES DETECTED:\n');
            console.log('=' .repeat(80));

            for (const disc of discrepancies) {
                console.log(`\nGroup: ${disc.groupName} (${disc.groupId})`);
                console.log(`User: ${disc.userName} (${disc.userId})`);
                console.log(`\n  Old (Expense-based):`);
                console.log(`    I Owe: ${disc.oldCalculation.iOwe.toLocaleString()} VND`);
                console.log(`    Owe Me: ${disc.oldCalculation.oweMe.toLocaleString()} VND`);
                console.log(`    Net Balance: ${disc.oldCalculation.netBalance.toLocaleString()} VND`);
                console.log(`\n  New (OriginalDebt-based):`);
                console.log(`    I Owe: ${disc.newCalculation.iOwe.toLocaleString()} VND`);
                console.log(`    Owe Me: ${disc.newCalculation.oweMe.toLocaleString()} VND`);
                console.log(`    Net Balance: ${disc.newCalculation.netBalance.toLocaleString()} VND`);
                console.log(`\n  ❌ Difference: ${disc.difference.toLocaleString()} VND`);
                console.log('-' .repeat(80));
            }

            console.log('\n⚠️  Action required: Review discrepancies above before deploying new calculation.');
        } else {
            console.log('\n✅ All calculations match! Safe to deploy.');
        }

    } catch (error) {
        console.error('❌ Error during verification:', error);
        throw error;
    } finally {
        await mongoose.disconnect();
        console.log('\n✅ Disconnected from MongoDB');
    }
}

// Run verification
if (require.main === module) {
    const maxGroups = process.argv[2] ? parseInt(process.argv[2]) : 50;
    verifyDebtConsistency(maxGroups)
        .then(() => {
            console.log('\n✅ Verification complete');
            process.exit(0);
        })
        .catch(error => {
            console.error('\n❌ Verification failed:', error);
            process.exit(1);
        });
}

export { verifyDebtConsistency };
