import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';

dotenv.config({ path: path.join(__dirname, '../.env') });

import { User } from '../src/models/User';
import { OriginalDebt } from '../src/models/OriginalDebt';

async function check() {
    try {
        await mongoose.connect(process.env.MONGODB_URI as string);
        const users = await User.find({});
        const results: Record<string, any> = {};
        for (const u of users) {
            const debts = await OriginalDebt.find({
                $or: [{ debtorId: u._id.toString() }, { creditorId: u._id.toString() }],
                remainingAmount: { $gt: 0.01 }
            });

            let owe = 0; let owed = 0;
            for (const d of debts) {
                if (d.debtorId === u._id.toString()) owe += d.remainingAmount;
                if (d.creditorId === u._id.toString()) owed += d.remainingAmount;
            }
            if (owe > 0 || owed > 0) {
                results[u.email] = { OWE: owe, OWED: owed, NET: owed - owe };
            }
        }
        fs.writeFileSync('check-original-debt.json', JSON.stringify(results, null, 2));
    } catch (e) {
        console.error(e);
    } finally {
        await mongoose.disconnect();
        process.exit();
    }
}
check();
