import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';

dotenv.config({ path: path.join(__dirname, '../.env') });

import { Transfer } from '../src/models/Transfer';
import { OriginalDebt } from '../src/models/OriginalDebt';

async function check() {
    try {
        await mongoose.connect(process.env.MONGODB_URI as string);
        const trans = await Transfer.find({});
        const debts = await OriginalDebt.find({ remainingAmount: { $gt: 0 } });

        fs.writeFileSync('check_transfers.json', JSON.stringify({
            transfers: trans,
            debts: debts
        }, null, 2));

    } catch (e) {
        console.error(e);
    } finally {
        await mongoose.disconnect();
        process.exit();
    }
}
check();
