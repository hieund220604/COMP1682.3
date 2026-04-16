import 'dotenv/config';
import mongoose from 'mongoose';
import { Group } from './src/models/Group';
import crypto from 'crypto';

async function run() {
    await mongoose.connect(process.env.MONGODB_URI || '');
    const groups = await Group.find({ joinCode: { $exists: false } });
    for (const g of groups) {
        g.joinCode = crypto.randomBytes(4).toString('hex').slice(0, 6).toUpperCase();
        await g.save();
        console.log('Updated', g.name, 'with code', g.joinCode);
    }
    console.log('Done');
    process.exit(0);
}
run();
