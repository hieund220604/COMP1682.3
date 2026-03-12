import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';

dotenv.config({ path: path.join(__dirname, '../.env') });

import { Transfer } from '../src/models/Transfer';
import { originalDebtService } from '../src/service/originalDebtService';

async function fixDebts() {
    try {
        await mongoose.connect(process.env.MONGODB_URI as string);

        // Find all COMPLETED transfers
        const completedTransfers = await Transfer.find({ status: 'COMPLETED' });
        console.log(`Found ${completedTransfers.length} completed transfers to apply.`);

        for (const t of completedTransfers) {
            // Re-apply the debt reduction for these transfers
            console.log(`Reducing debt by ${t.amount} from ${t.fromUserId} to ${t.toUserId} in group ${t.groupId}`);
            await originalDebtService.reduceDebtsBetweenUsers(
                t.groupId,
                t.fromUserId,
                t.toUserId,
                t.amount
            );
        }
        console.log("Finished syncing Original Debt with Completed Transfers.");
    } catch (e) {
        console.error(e);
    } finally {
        await mongoose.disconnect();
        process.exit();
    }
}
fixDebts();
