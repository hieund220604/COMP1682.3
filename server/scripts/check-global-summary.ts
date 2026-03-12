import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';
import fs from 'fs';

dotenv.config({ path: path.join(__dirname, '../.env') });

import { User } from '../src/models/User';
import { originalDebtService } from '../src/service/originalDebtService';

async function check() {
    try {
        await mongoose.connect(process.env.MONGODB_URI as string);
        const users = await User.find({});
        const results: Record<string, any> = {};
        for (const u of users) {
            const summary = await originalDebtService.getUserGlobalDebtSummary(u._id.toString());
            results[u.email] = summary;
        }
        fs.writeFileSync('check_output.json', JSON.stringify(results, null, 2));
    } catch (e) {
        console.error(e);
    } finally {
        await mongoose.disconnect();
        process.exit();
    }
}
check();
