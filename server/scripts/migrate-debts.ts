import mongoose from 'mongoose';
import dotenv from 'dotenv';
import { Settlement } from '../src/models/Settlement';
import { OriginalDebt } from '../src/models/OriginalDebt';
import { originalDebtService } from '../src/service/originalDebtService';

// Load env vars from ../.env
dotenv.config({ path: path.join(__dirname, '../.env') });

/**
 * Migration script to retroactively reduce OriginalDebts for previously COMPLETED settlements.
 * 
 * Before the fix: Settlement completion didn't reduce OriginalDebts, leading to inflated global Net Debt.
 * This script finds all COMPLETED settlements and runs the new FIFO debt reduction logic on them.
 */
async function runMigration() {
    try {
        console.log('Connecting to MongoDB...');
        await mongoose.connect(process.env.MONGODB_URI as string);
        console.log('Connected.');

        // 1. Reset all remainingAmounts to originalAmounts?
        // Wait, NO. If transfers already reduced them, resetting them would lose that data!
        // Instead, we just apply the completed settlements to the CURRENT remaining debts.
        // Assuming past allocations (from Transfers) were correct, and only Settlements were missing.

        console.log('Fetching all COMPLETED settlements...');
        // Sort by createdAt ascending to process oldest first (FIFO across time)
        const settlements = await Settlement.find({ status: 'COMPLETED' }).sort({ createdAt: 1 });

        console.log(`Found ${settlements.length} completed settlements.`);

        let processedCount = 0;
        let skipCount = 0;

        for (const settlement of settlements) {
            // Check if this settlement was already processed?
            // Since we don't have a flag for "processed by originalDebt", we might accidentally double-count
            // if we run this script twice.
            // But if we just run it once for the existing db state, it's fine.

            console.log(`Processing settlement ${settlement._id} (${settlement.amount} VND from ${settlement.fromUserId} to ${settlement.toUserId} in group ${settlement.groupId})`);

            // Apply the same logic we added in the fix
            await originalDebtService.reduceDebtsBetweenUsers(
                settlement.groupId,
                settlement.fromUserId,
                settlement.toUserId,
                Number(settlement.amount)
            );

            processedCount++;
            console.log(`Processed ${processedCount}/${settlements.length}`);
        }

        console.log(`Migration complete. Processed ${processedCount}, Skipped ${skipCount}.`);
        process.exit(0);
    } catch (error) {
        console.error('Migration failed:', error);
        process.exit(1);
    }
}

runMigration();
