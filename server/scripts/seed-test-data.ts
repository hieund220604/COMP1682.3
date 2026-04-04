/**
 * Seed rich demo data for SplitPal API without sending emails or running schedulers.
 * - Drops the current MongoDB database (be careful!)
 * - Creates users, groups, invoices, payment requests, transfers, subscriptions, wallets, chats, notifications
 * - Names/codes are prefixed so you can scan quickly in responses or Mongo Compass.
 *
 * Run (dev only):
 *   npm run seed:test
 *
 * Flags:
 *   --force   bypass NODE_ENV=production guard
 */
import 'dotenv/config';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';

import { connectDB, disconnectDB } from '../src/db';
import { connectRedis, deleteKeysByPrefix } from '../src/redis';
import { User } from '../src/models/User';
import { Group } from '../src/models/Group';
import { GroupMember } from '../src/models/GroupMember';
import { Invite } from '../src/models/Invite';
import { Invoice } from '../src/models/Invoice';
import { InvoiceItem } from '../src/models/InvoiceItem';
import { OriginalDebt } from '../src/models/OriginalDebt';
import { PaymentRequest } from '../src/models/PaymentRequest';
import { Transfer } from '../src/models/Transfer';
import { TransferDebtAllocation } from '../src/models/TransferDebtAllocation';
import { Subscription } from '../src/models/Subscription';
import { SubscriptionMember } from '../src/models/SubscriptionMember';
import { BillingHistory } from '../src/models/BillingHistory';
import { TopUp } from '../src/models/TopUp';
import { Withdrawal } from '../src/models/Withdrawal';
import { Transaction } from '../src/models/Transaction';
import { Message } from '../src/models/Message';
import { Notification, NotificationType } from '../src/models/Notification';

const isProd = process.env.NODE_ENV === 'production';
const force = process.argv.includes('--force');

if (isProd && !force) {
    console.error('Refusing to seed: NODE_ENV=production. Use --force if you are absolutely sure.');
    process.exit(1);
}

type Ref<T> = string;

async function dropDatabase() {
    const conn = mongoose.connection;
    if (!conn || !conn.db) {
        throw new Error('MongoDB not connected. Call connectDB() first.');
    }
    await conn.dropDatabase();
    console.log('✓ Dropped existing database');
}

async function maybeFlushRedis() {
    try {
        await connectRedis();
        await deleteKeysByPrefix('splitpal:');
        console.log('✓ Flushed Redis keys with prefix splitpal:');
    } catch {
        console.log('ℹ Redis not configured or flush skipped');
    }
}

async function seed() {
    console.log('🌱 Seeding SplitPal demo data (test)...');
    await connectDB();
    await dropDatabase();
    await maybeFlushRedis();

    const passwordHash = await bcrypt.hash('Test@123', 10);

    // --- USERS -------------------------------------------------------------
    const userData = Array.from({ length: 12 }).map((_, i) => ({
        email: `test${i + 1}@gmail.com`,
        passwordHash,
        displayName: `User ${i + 1}`,
        status: 'active',
        balance: [5_000_000, 4_000_000, 2_000_000, 1_500_000, 3_200_000, 800_000, 1_000_000, 500_000, 1_500_000, 700_000, 1_200_000, 900_000][i],
        currency: 'VND',
        pushNotificationsEnabled: i !== 6, // U7 disabled to test preference
        fcmToken: i < 2 ? `demo-fcm-token-${i + 1}` : null
    }));
    const users = await User.create(userData);
    const U = (n: number) => users[n - 1]._id.toString();

    // --- GROUPS -----------------------------------------------------------
    const groups = await Group.create([
        { name: 'G1-LUNCH (VND)', baseCurrency: 'VND', createdBy: U(1) },
        { name: 'G2-TRIP-USD (USD base)', baseCurrency: 'USD', createdBy: U(2) },
        { name: 'G3-SUB-LUNCH (VND)', baseCurrency: 'VND', createdBy: U(1) },
        { name: 'G4-DORM-BILLS (VND)', baseCurrency: 'VND', createdBy: U(4) },
        { name: 'G5-PLAYGROUND (VND)', baseCurrency: 'VND', createdBy: U(10) },
        { name: 'G6-ARCHIVE (VND)', baseCurrency: 'VND', createdBy: U(5) }
    ]);
    const G = (n: number) => groups[n - 1]._id.toString();

    // --- GROUP MEMBERS ----------------------------------------------------
    await GroupMember.create([
        // G1
        { groupId: G(1), userId: U(1), role: 'OWNER' },
        { groupId: G(1), userId: U(2), role: 'ADMIN' },
        { groupId: G(1), userId: U(3), role: 'USER' },
        { groupId: G(1), userId: U(4), role: 'USER' },
        { groupId: G(1), userId: U(6), role: 'USER', leftAt: new Date(Date.now() - 7 * 86400000) },
        // G2
        { groupId: G(2), userId: U(2), role: 'OWNER' },
        { groupId: G(2), userId: U(3), role: 'ADMIN' },
        { groupId: G(2), userId: U(5), role: 'USER' },
        { groupId: G(2), userId: U(6), role: 'USER' },
        { groupId: G(2), userId: U(7), role: 'USER' },
        // G3
        { groupId: G(3), userId: U(1), role: 'OWNER' },
        { groupId: G(3), userId: U(7), role: 'ADMIN' },
        { groupId: G(3), userId: U(8), role: 'USER' },
        { groupId: G(3), userId: U(9), role: 'USER' },
        // G4
        { groupId: G(4), userId: U(4), role: 'OWNER' },
        { groupId: G(4), userId: U(1), role: 'ADMIN' },
        { groupId: G(4), userId: U(10), role: 'USER' },
        // G5
        { groupId: G(5), userId: U(10), role: 'OWNER' },
        { groupId: G(5), userId: U(11), role: 'USER' },
        // G6 (historical)
        { groupId: G(6), userId: U(5), role: 'OWNER' },
        { groupId: G(6), userId: U(12), role: 'USER', leftAt: new Date(Date.now() - 30 * 86400000) }
    ]);

    // --- INVITES ----------------------------------------------------------
    await Invite.create([
        {
            groupId: G(1),
            emailInvite: 'u11+g1@example.com',
            role: 'USER',
            token: 'INV-G1-U11',
            status: 'PENDING',
            expiredAt: new Date(Date.now() + 7 * 86400000),
            invitedBy: U(1)
        },
        {
            groupId: G(2),
            emailInvite: 'expired@trip.com',
            role: 'USER',
            token: 'INV-G2-EXP',
            status: 'EXPIRED',
            expiredAt: new Date(Date.now() - 3 * 86400000),
            invitedBy: U(2)
        },
        {
            groupId: G(5),
            emailInvite: 'newbie@example.com',
            role: 'USER',
            token: 'INV-G5-PENDING',
            status: 'PENDING',
            expiredAt: new Date(Date.now() + 10 * 86400000),
            invitedBy: U(10)
        }
    ]);

    // --- INVOICES + ITEMS + DEBTS ----------------------------------------
    const invoices = await Invoice.create([
        { groupId: G(1), title: 'INV-G1-GROCERIES (EQUAL)', amountTotal: 600_000, currency: 'VND', uploadedBy: U(1), status: 'SUBMITTED', isLocked: false, note: 'Lunch staples' },
        { groupId: G(1), title: 'INV-G1-ELEC-PCT (PERCENTAGE)', amountTotal: 400_000, currency: 'VND', uploadedBy: U(2), status: 'SUBMITTED', isLocked: false, note: 'Electricity split by usage' },
        { groupId: G(1), title: 'INV-G1-ADJ (Adjustment)', amountTotal: -50_000, currency: 'VND', uploadedBy: U(1), status: 'SUBMITTED', isLocked: false, isAdjustment: true, originalInvoiceId: undefined },
        { groupId: G(2), title: 'INV-G2-JPY-TRAIN (FX EQUAL)', amountTotal: 40_000, currency: 'JPY', uploadedBy: U(2), status: 'SUBMITTED', isLocked: false, baseCurrency: 'USD', exchangeRate: 0.0066, convertedAmountTotal: 264, note: 'Shinkansen tickets' },
        { groupId: G(2), title: 'INV-G2-USD-AIRBNB (WEIGHT)', amountTotal: 480, currency: 'USD', uploadedBy: U(3), status: 'SUBMITTED', isLocked: false, baseCurrency: 'USD', note: 'Airbnb 3 nights' },
        { groupId: G(4), title: 'INV-G4-WATER-INET (CUSTOM)', amountTotal: 700_000, currency: 'VND', uploadedBy: U(4), status: 'SUBMITTED', isLocked: false, note: 'Water+Internet split custom' }
    ]);
    const I = (n: number) => invoices[n - 1]._id.toString();

    // Invoice items
    await InvoiceItem.create([
        // I1 Groceries equal U2 U3 U4
        { invoiceId: I(1), name: 'Groceries pack', amount: 600_000, splitType: 'EQUAL', assignedTo: [U(2), U(3), U(4)] },
        // I2 Electricity percentage: U2 50%, U3 30%, U4 20%
        { invoiceId: I(2), name: 'Electricity Jan', amount: 400_000, splitType: 'PERCENTAGE', assignedTo: [U(2), U(3), U(4)], splits: [{ userId: U(2), value: 50 }, { userId: U(3), value: 30 }, { userId: U(4), value: 20 }] },
        // I3 Adjustment negative to reduce grocery
        { invoiceId: I(3), name: 'Adjustment', amount: -50_000, splitType: 'EQUAL', assignedTo: [U(2), U(3), U(4)] },
        // I4 JPY train equal U2 U3 U5 U6
        { invoiceId: I(4), name: 'Train tickets', amount: 40_000, splitType: 'EQUAL', assignedTo: [U(2), U(3), U(5), U(6)] },
        // I5 Airbnb weight U2 weight2, U3 weight1, U5 weight1
        { invoiceId: I(5), name: 'Airbnb 3 nights', amount: 480, splitType: 'WEIGHT', assignedTo: [U(2), U(3), U(5)], splits: [{ userId: U(2), value: 2 }, { userId: U(3), value: 1 }, { userId: U(5), value: 1 }] },
        // I6 Water/Internet custom U4 300k, U10 200k, U1 200k
        { invoiceId: I(6), name: 'Water+Internet', amount: 700_000, splitType: 'CUSTOM', assignedTo: [U(4), U(10), U(1)], splits: [{ userId: U(4), value: 300_000 }, { userId: U(10), value: 200_000 }, { userId: U(1), value: 200_000 }] }
    ]);

    // Manual Original Debts (amounts in group baseCurrency)
    const debts = await OriginalDebt.create([
        { groupId: G(1), invoiceId: I(1), debtorId: U(2), creditorId: U(1), originalAmount: 200_000, remainingAmount: 200_000 },
        { groupId: G(1), invoiceId: I(1), debtorId: U(3), creditorId: U(1), originalAmount: 200_000, remainingAmount: 200_000 },
        { groupId: G(1), invoiceId: I(1), debtorId: U(4), creditorId: U(1), originalAmount: 200_000, remainingAmount: 200_000 },
        { groupId: G(1), invoiceId: I(2), debtorId: U(2), creditorId: U(2), originalAmount: 0, remainingAmount: 0 }, // uploader owes nothing extra
        { groupId: G(1), invoiceId: I(2), debtorId: U(3), creditorId: U(2), originalAmount: 120_000, remainingAmount: 120_000 },
        { groupId: G(1), invoiceId: I(2), debtorId: U(4), creditorId: U(2), originalAmount: 80_000, remainingAmount: 80_000 },
        { groupId: G(2), invoiceId: I(4), debtorId: U(2), creditorId: U(2), originalAmount: 0, remainingAmount: 0 },
        { groupId: G(2), invoiceId: I(4), debtorId: U(3), creditorId: U(2), originalAmount: 66, remainingAmount: 66, originalCurrency: 'JPY', originalAmountInCurrency: 10_000, exchangeRateUsed: 0.0066, rateLockedAt: new Date() },
        { groupId: G(2), invoiceId: I(4), debtorId: U(5), creditorId: U(2), originalAmount: 66, remainingAmount: 66, originalCurrency: 'JPY', originalAmountInCurrency: 10_000, exchangeRateUsed: 0.0066, rateLockedAt: new Date() },
        { groupId: G(2), invoiceId: I(4), debtorId: U(6), creditorId: U(2), originalAmount: 66, remainingAmount: 66, originalCurrency: 'JPY', originalAmountInCurrency: 10_000, exchangeRateUsed: 0.0066, rateLockedAt: new Date() },
        { groupId: G(2), invoiceId: I(5), debtorId: U(2), creditorId: U(3), originalAmount: 240, remainingAmount: 240 }, // uploader U3
        { groupId: G(2), invoiceId: I(5), debtorId: U(3), creditorId: U(3), originalAmount: 0, remainingAmount: 0 },
        { groupId: G(2), invoiceId: I(5), debtorId: U(5), creditorId: U(3), originalAmount: 120, remainingAmount: 120 },
        { groupId: G(4), invoiceId: I(6), debtorId: U(4), creditorId: U(4), originalAmount: 0, remainingAmount: 0 },
        { groupId: G(4), invoiceId: I(6), debtorId: U(10), creditorId: U(4), originalAmount: 200_000, remainingAmount: 0 }, // paid via PR later
        { groupId: G(4), invoiceId: I(6), debtorId: U(1), creditorId: U(4), originalAmount: 200_000, remainingAmount: 0 }
    ]);
    const D = (n: number) => debts[n - 1]._id.toString();

    // --- PAYMENT REQUESTS & TRANSFERS ------------------------------------
    const prs = await PaymentRequest.create([
        { groupId: G(1), createdBy: U(1), invoiceIds: [I(1), I(2)], status: 'PARTIALLY_PAID', issuedAt: new Date(Date.now() - 3 * 86400000), expiresAt: new Date(Date.now() + 4 * 86400000) },
        { groupId: G(2), createdBy: U(2), invoiceIds: [I(4)], status: 'ISSUED', issuedAt: new Date(Date.now() - 1 * 86400000), expiresAt: new Date(Date.now() + 6 * 86400000) },
        { groupId: G(4), createdBy: U(4), invoiceIds: [I(6)], status: 'PAID', issuedAt: new Date(Date.now() - 10 * 86400000), paidAt: new Date(Date.now() - 8 * 86400000) },
        { groupId: G(2), createdBy: U(3), invoiceIds: [I(5)], status: 'CANCELLED', issuedAt: new Date(Date.now() - 15 * 86400000), cancelledAt: new Date(Date.now() - 12 * 86400000), expiresAt: new Date(Date.now() - 13 * 86400000) }
    ]);
    const PR = (n: number) => prs[n - 1]._id.toString();

    // Update invoices with PR linkage/lock
    await Invoice.updateMany({ _id: { $in: [I(1), I(2)] } }, { paymentRequestId: PR(1), isLocked: true, status: 'LOCKED' });
    await Invoice.updateMany({ _id: I(4) }, { paymentRequestId: PR(2), isLocked: true, status: 'LOCKED' });
    await Invoice.updateMany({ _id: I(6) }, { paymentRequestId: PR(3), isLocked: true, status: 'LOCKED' });

    const transfers = await Transfer.create([
        { paymentRequestId: PR(1), groupId: G(1), fromUserId: U(2), toUserId: U(1), amount: 200_000, status: 'COMPLETED', paidAt: new Date(Date.now() - 2 * 86400000) },
        { paymentRequestId: PR(1), groupId: G(1), fromUserId: U(3), toUserId: U(1), amount: 200_000, status: 'PENDING', otp: '111222', otpExpiresAt: new Date(Date.now() + 60 * 60 * 1000), otpVerified: false },
        { paymentRequestId: PR(1), groupId: G(1), fromUserId: U(4), toUserId: U(1), amount: 200_000, status: 'CANCELLED' },
        { paymentRequestId: PR(2), groupId: G(2), fromUserId: U(5), toUserId: U(2), amount: 120, status: 'PENDING', otp: '222333', otpExpiresAt: new Date(Date.now() + 90 * 60 * 1000), otpVerified: false, originalCurrency: 'USD', exchangeRate: 1 },
        { paymentRequestId: PR(2), groupId: G(2), fromUserId: U(6), toUserId: U(2), amount: 66, status: 'PENDING', otp: '222333', otpExpiresAt: new Date(Date.now() + 90 * 60 * 1000), otpVerified: false, originalCurrency: 'JPY', exchangeRate: 0.0066 },
        { paymentRequestId: PR(3), groupId: G(4), fromUserId: U(10), toUserId: U(4), amount: 200_000, status: 'COMPLETED', paidAt: new Date(Date.now() - 9 * 86400000) },
        { paymentRequestId: PR(3), groupId: G(4), fromUserId: U(1), toUserId: U(4), amount: 200_000, status: 'COMPLETED', paidAt: new Date(Date.now() - 9 * 86400000) }
    ]);
    const T = (n: number) => transfers[n - 1]._id.toString();

    await TransferDebtAllocation.create([
        { transferId: T(1), originalDebtId: D(1), allocatedAmount: 200_000 },
        { transferId: T(2), originalDebtId: D(2), allocatedAmount: 200_000 },
        { transferId: T(3), originalDebtId: D(3), allocatedAmount: 200_000 },
        { transferId: T(4), originalDebtId: D(11), allocatedAmount: 120 },
        { transferId: T(5), originalDebtId: D(8), allocatedAmount: 66 },
        { transferId: T(6), originalDebtId: D(15), allocatedAmount: 200_000 },
        { transferId: T(7), originalDebtId: D(16), allocatedAmount: 200_000 }
    ]);

    // Reduce paid debts
    await OriginalDebt.findByIdAndUpdate(D(1), { remainingAmount: 0 });
    await OriginalDebt.findByIdAndUpdate(D(3), { remainingAmount: 0 });
    await OriginalDebt.findByIdAndUpdate(D(15), { remainingAmount: 0 });
    await OriginalDebt.findByIdAndUpdate(D(16), { remainingAmount: 0 });

    // --- SUBSCRIPTIONS & BILLING -----------------------------------------
    const subs = await Subscription.create([
        { groupId: G(3), name: 'SUB-G3-LUNCH', amount: 400_000, currency: 'VND', billingCycle: 'MONTHLY', status: 'ACTIVE', nextBillingDate: new Date(Date.now() - 86400000), createdBy: U(1), retryCount: 0 },
        { groupId: G(3), name: 'SUB-G3-COFFEE', amount: 200_000, currency: 'VND', billingCycle: 'MONTHLY', status: 'PAUSED', nextBillingDate: new Date(Date.now() + 20 * 86400000), createdBy: U(1), retryCount: 0 },
        { groupId: G(3), name: 'SUB-G3-PRINTER', amount: 300_000, currency: 'VND', billingCycle: 'MONTHLY', status: 'PAST_DUE', nextBillingDate: new Date(Date.now() - 10 * 86400000), createdBy: U(7), retryCount: 1, lastAttemptAt: new Date(Date.now() - 2 * 86400000) }
    ]);
    const S = (n: number) => subs[n - 1]._id.toString();

    await SubscriptionMember.create([
        { subscriptionId: S(1), userId: U(1), shareAmount: 100_000, status: 'ACTIVE' },
        { subscriptionId: S(1), userId: U(7), shareAmount: 100_000, status: 'ACTIVE' },
        { subscriptionId: S(1), userId: U(8), shareAmount: 100_000, status: 'ACTIVE' },
        { subscriptionId: S(1), userId: U(9), shareAmount: 100_000, status: 'ACTIVE' },
        { subscriptionId: S(2), userId: U(1), shareAmount: 100_000, status: 'PAUSED' },
        { subscriptionId: S(2), userId: U(8), shareAmount: 100_000, status: 'PAUSED' },
        { subscriptionId: S(3), userId: U(7), shareAmount: 150_000, status: 'ACTIVE' },
        { subscriptionId: S(3), userId: U(9), shareAmount: 150_000, status: 'ACTIVE' }
    ]);

    await BillingHistory.create([
        {
            subscriptionId: S(1),
            groupId: G(3),
            billingDate: new Date(Date.now() - 86400000),
            amount: 400_000,
            currency: 'VND',
            status: 'SUCCESS',
            membersCharged: 4,
            membersFailed: 0,
            totalCollected: 400_000,
            memberResults: [
                { userId: U(1), shareAmount: 100_000, success: true },
                { userId: U(7), shareAmount: 100_000, success: true },
                { userId: U(8), shareAmount: 100_000, success: true },
                { userId: U(9), shareAmount: 100_000, success: true }
            ]
        },
        {
            subscriptionId: S(3),
            groupId: G(3),
            billingDate: new Date(Date.now() - 3 * 86400000),
            amount: 300_000,
            currency: 'VND',
            status: 'FAILED',
            membersCharged: 0,
            membersFailed: 2,
            totalCollected: 0,
            failureReason: 'Insufficient balance U9',
            memberResults: [
                { userId: U(7), shareAmount: 150_000, success: false, reason: 'Insufficient balance' },
                { userId: U(9), shareAmount: 150_000, success: false, reason: 'Insufficient balance' }
            ]
        }
    ]);

    // --- TOPUPS & WITHDRAWALS & TRANSACTIONS ------------------------------
    const topUps = await TopUp.create([
        { userId: U(1), amount: 1_000_000, status: 'COMPLETED', vnpayTxnRef: 'VNPAY001' },
        { userId: U(3), amount: 500_000, status: 'PENDING' },
        { userId: U(4), amount: 300_000, status: 'FAILED' }
    ]);
    const WDs = await Withdrawal.create([
        { userId: U(7), amount: 400_000, currency: 'VND', accountNumber: '1234567890', bankName: 'VCB', accountName: 'User 7', status: 'COMPLETED', verifiedAt: new Date(Date.now() - 5 * 86400000), processedAt: new Date(Date.now() - 5 * 86400000) },
        { userId: U(5), amount: 200_000, currency: 'VND', accountNumber: '9876543210', bankName: 'TCB', accountName: 'User 5', status: 'OTP_SENT', otp: '654321', otpExpiresAt: new Date(Date.now() + 10 * 60 * 1000) },
        { userId: U(6), amount: 150_000, currency: 'VND', accountNumber: '1122334455', bankName: 'ACB', accountName: 'User 6', status: 'PROCESSING' },
        { userId: U(9), amount: 120_000, currency: 'VND', accountNumber: '5566778899', bankName: 'BIDV', accountName: 'User 9', status: 'REJECTED' }
    ]);

    // Transactions (balances are illustrative)
    await Transaction.create([
        { userId: U(1), type: 'TOP_UP', amount: 1_000_000, balanceBefore: 4_000_000, balanceAfter: 5_000_000, currency: 'VND', description: 'TopUp VNPAY001', referenceId: topUps[0]._id.toString(), referenceType: 'TopUp' },
        { userId: U(2), type: 'SETTLEMENT_RECEIVED', amount: 200_000, balanceBefore: 4_000_000, balanceAfter: 4_200_000, currency: 'VND', description: 'Transfer from U2 -> U1', referenceId: T(1), referenceType: 'Transfer' },
        { userId: U(7), type: 'WITHDRAWAL', amount: -400_000, balanceBefore: 1_400_000, balanceAfter: 1_000_000, currency: 'VND', description: 'Withdrawal completed', referenceId: WDs[0]._id.toString(), referenceType: 'Withdrawal' },
        { userId: U(8), type: 'SUBSCRIPTION_FEE', amount: -100_000, balanceBefore: 600_000, balanceAfter: 500_000, currency: 'VND', description: 'SUB-G3-LUNCH', referenceType: 'Subscription' },
        { userId: U(1), type: 'SUBSCRIPTION_FEE', amount: -100_000, balanceBefore: 5_000_000, balanceAfter: 4_900_000, currency: 'VND', description: 'SUB-G3-LUNCH', referenceType: 'Subscription' },
        { userId: U(10), type: 'TRANSFER_SENT', amount: -200_000, balanceBefore: 900_000, balanceAfter: 700_000, currency: 'VND', description: 'PR-G4-PAID', referenceId: T(6), referenceType: 'Transfer' },
        { userId: U(4), type: 'TRANSFER_RECEIVED', amount: 200_000, balanceBefore: 1_300_000, balanceAfter: 1_500_000, currency: 'VND', description: 'PR-G4-PAID', referenceId: T(6), referenceType: 'Transfer' }
    ]);

    // --- MESSAGES ---------------------------------------------------------
    await Message.create([
        { groupId: G(1), senderId: U(1), content: '[G1] Created lunch group', messageType: 'TEXT' },
        { groupId: G(1), senderId: U(2), content: '[G1] Groceries added INV-G1-GROCERIES', messageType: 'TEXT' },
        { groupId: G(2), senderId: U(2), content: '[G2] Trip tickets invoice INV-G2-JPY-TRAIN', messageType: 'TEXT' },
        { groupId: G(2), senderId: U(3), content: '[G2] Airbnb split WEIGHT (2/1/1)', messageType: 'TEXT' },
        { groupId: G(3), senderId: U(7), content: '[G3] SUB-G3-LUNCH will bill monthly', messageType: 'TEXT' },
        { groupId: G(4), senderId: U(4), content: '[G4] Water/Internet custom split', messageType: 'TEXT' },
        { groupId: G(1), senderId: U(3), content: '[G1] Upload receipt', messageType: 'FILE', fileUrl: 'https://example.com/receipt.jpg', fileName: 'receipt.jpg' }
    ]);

    // --- NOTIFICATIONS ----------------------------------------------------
    await Notification.create([
        { userId: U(2), type: NotificationType.EXPENSE_CREATED, title: 'Expense', message: 'INV-G1-GROCERIES created', data: { groupId: G(1), invoiceId: I(1) }, read: false, sentEmail: false },
        { userId: U(1), type: NotificationType.PAYMENT_RECEIVED, title: 'Transfer received', message: '200,000 VND from User 2 (PR-G1-PARTIAL)', data: { transferId: T(1) }, read: true, sentEmail: true },
        { userId: U(11), type: NotificationType.INVITE_RECEIVED, title: 'Invite', message: 'You are invited to G5-PLAYGROUND', data: { token: 'INV-G5-PENDING' }, read: false, sentEmail: false },
        { userId: U(7), type: NotificationType.SUBSCRIPTION_BILLING_FAILED, title: 'Billing failed', message: 'SUB-G3-PRINTER attempt failed', data: { subscriptionId: S(3) }, read: false, sentEmail: false },
        { userId: U(3), type: NotificationType.PAYMENT_REQUEST_REMINDER, title: 'PR reminder', message: 'PR-G2-ISSUED pending payments', data: { paymentRequestId: PR(2) }, read: false, sentEmail: false },
        { userId: U(6), type: NotificationType.ROLE_CHANGED, title: 'Role changed', message: 'Your push notifications disabled for demo', data: { groupId: G(1) }, read: true, sentEmail: false }
    ]);

    // --- SUMMARY ----------------------------------------------------------
    console.log('\n✅ Seed completed. Key facts:');
    console.log('- Login users: test1..test12@gmail.com / Test@123');
    console.log('- Groups: G1-LUNCH, G2-TRIP-USD, G3-SUB-LUNCH, G4-DORM-BILLS, G5-PLAYGROUND, G6-ARCHIVE');
    console.log('- Payment Requests:');
    console.log(`  PR1 ${PR(1)} G1 PARTIALLY_PAID (T2 pending OTP 111222)`);
    console.log(`  PR2 ${PR(2)} G2 ISSUED (OTP 222333)`);
    console.log(`  PR3 ${PR(3)} G4 PAID`);
    console.log(`  PR4 ${PR(4)} G2 CANCELLED`);
    console.log('- Withdraw OTP: W-U5 OTP 654321');
    console.log('- Foreign currency invoice: INV-G2-JPY-TRAIN (JPY->USD), INV-G2-USD-AIRBNB (USD WEIGHT)');
    console.log('- Subscriptions: SUB-G3-LUNCH ACTIVE, SUB-G3-COFFEE PAUSED, SUB-G3-PRINTER PAST_DUE');
}

seed()
    .catch((err) => {
        console.error('❌ Seed failed:', err);
        process.exitCode = 1;
    })
    .finally(async () => {
        await disconnectDB();
        process.exit();
    });
