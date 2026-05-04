import mongoose from 'mongoose';
import { User } from './src/models/User';
import { GroupMember } from './src/models/GroupMember';
import { Group } from './src/models/Group';
import { BillTemplate } from './src/models/BillTemplate';
import dotenv from 'dotenv';

dotenv.config();

async function run() {
    try {
        await mongoose.connect(process.env.MONGODB_URI as string);
        console.log('Connected to DB');
        
        // 1. Revert all users to free
        await User.updateMany({}, { $set: { isPro: false } });
        console.log('Reverted all users to FREE (isPro: false)');

        // 2. Find user
        const user = await User.findOne({ email: 'test@example.com' });
        if (!user) {
            console.log('User test@example.com not found');
            process.exit(0);
        }

        // 3. Find a group where user is member
        const member = await GroupMember.findOne({ userId: user._id, leftAt: null });
        let groupId;
        if (!member) {
            console.log('User has no group. Creating a test group...');
            const group = await Group.create({
                name: 'Test Group for Templates',
                baseCurrency: 'VND',
                createdBy: user._id,
                joinCode: 'TEST12'
            });
            await GroupMember.create({
                groupId: group._id,
                userId: user._id,
                role: 'OWNER'
            });
            groupId = group._id;
        } else {
            groupId = member.groupId;
        }

        // 4. Check template count
        const existingCount = await BillTemplate.countDocuments({ createdBy: user._id, status: { $ne: 'ARCHIVED' } });
        console.log(`User currently has ${existingCount} templates.`);

        // 5. Create enough templates to reach 2
        for (let i = existingCount; i < 2; i++) {
            await BillTemplate.create({
                groupId: groupId,
                name: `Test Template ${i + 1}`,
                description: 'Mock template for testing PRO limit',
                billingCycle: 'MONTHLY',
                billingDay: 1,
                currency: 'VND',
                items: [
                    {
                        name: 'Mock Item',
                        amount: 100000,
                        splitType: 'EQUAL',
                        assignedTo: [user._id],
                        splits: []
                    }
                ],
                payerId: user._id,
                status: 'ACTIVE',
                createdBy: user._id,
                nextBillDate: new Date()
            });
            console.log(`Created mock template ${i + 1}`);
        }

        console.log('Done! test@example.com now has 2 templates and is a FREE account.');
        process.exit(0);
    } catch (e) {
        console.error(e);
        process.exit(1);
    }
}

run();
