import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';

// Load env vars from the correct path
dotenv.config({ path: path.join(__dirname, '../.env') });

import { Settlement } from '../src/models/Settlement';
import { Transfer } from '../src/models/Transfer';
import { PaymentRequest } from '../src/models/PaymentRequest';

async function migrate() {
    try {
        if (!process.env.MONGODB_URI) {
            throw new Error('MONGODB_URI is not defined in .env');
        }

        console.log('Connecting to database...');
        await mongoose.connect(process.env.MONGODB_URI);
        console.log('Connected successfully.');

        const settlements = await Settlement.find({});
        console.log(`Found ${settlements.length} total settlements.`);

        let migratedCount = 0;
        let skippedCount = 0;

        for (const settlement of settlements) {
            // Check if already migrated by seeing if a Transfer exists with identical core properties
            const existingTransfer = await Transfer.findOne({
                fromUserId: settlement.fromUserId,
                toUserId: settlement.toUserId,
                amount: settlement.amount,
                createdAt: settlement.createdAt
            });

            if (existingTransfer) {
                console.log(`Skipping settlement ${settlement._id.toString()} - already migrated.`);
                skippedCount++;
                continue;
            }

            // Create a dummy PaymentRequest for the settlement
            const paymentRequest = await PaymentRequest.create({
                groupId: settlement.groupId,
                createdBy: settlement.fromUserId,
                invoiceIds: [], // Empty because it's a legacy direct settlement
                status: settlement.status === 'COMPLETED' ? 'PAID' : 'ISSUED',
                issuedAt: settlement.createdAt,
                paidAt: settlement.status === 'COMPLETED' ? (settlement.vnpayTransDate || settlement.createdAt) : undefined,
                createdAt: settlement.createdAt
            });

            // Create corresponding Transfer
            await Transfer.create({
                paymentRequestId: paymentRequest._id.toString(),
                groupId: settlement.groupId,
                fromUserId: settlement.fromUserId,
                toUserId: settlement.toUserId,
                amount: settlement.amount,
                status: settlement.status,
                vnpayTxnRef: settlement.vnpayTxnRef,
                vnpayTransDate: settlement.vnpayTransDate,
                paidAt: settlement.status === 'COMPLETED' ? (settlement.vnpayTransDate || settlement.createdAt) : undefined,
                otpVerified: settlement.status === 'COMPLETED',
                createdAt: settlement.createdAt
            });

            console.log(`Migrated settlement ${settlement._id.toString()} successfully.`);
            migratedCount++;
        }

        console.log(`\nMigration complete! \nMigrated: ${migratedCount} \nSkipped: ${skippedCount}\n`);
    } catch (error) {
        console.error('Migration failed:', error);
    } finally {
        await mongoose.disconnect();
        console.log('Disconnected from database.');
        process.exit(0);
    }
}

migrate();
