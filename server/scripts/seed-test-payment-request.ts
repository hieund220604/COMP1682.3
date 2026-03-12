import mongoose from 'mongoose';
import dotenv from 'dotenv';
import path from 'path';
import { User } from '../src/models/User';
import { Group } from '../src/models/Group';
import { GroupMember } from '../src/models/GroupMember';
import { Invoice } from '../src/models/Invoice';
import { InvoiceItem } from '../src/models/InvoiceItem';
import { OriginalDebt } from '../src/models/OriginalDebt';

dotenv.config({ path: path.join(__dirname, '../.env') });

/**
 * Seed script: Creates 3 test users (A, B, C) in a group,
 * each uploads an invoice assigned to the other two.
 *
 * After running this script:
 *   - 3 users with 1,000,000 VND balance each
 *   - 1 group "Test Payment Flow"
 *   - 3 invoices (SUBMITTED, unlocked)
 *   - 6 OriginalDebt records (cross-debts)
 *
 * You can then test:
 *   1. Create payment request → generates optimized transfers
 *   2. Some users pay, one cancels → full cancel + refund
 *   3. Create new payment request → recalculates remaining debts
 *
 * Usage:
 *   npx ts-node scripts/seed-test-payment-request.ts
 *   npx ts-node scripts/seed-test-payment-request.ts --clean   (remove test data)
 */

const TEST_PREFIX = '__TEST_PR__';

async function clean() {
    console.log('🧹 Cleaning up test data...');

    const users = await User.find({ displayName: { $regex: `^${TEST_PREFIX}` } });
    const userIds = users.map(u => u._id.toString());

    if (userIds.length === 0) {
        console.log('No test data found.');
        return;
    }

    const groups = await Group.find({ createdBy: { $in: userIds } });
    const groupIds = groups.map(g => g._id.toString());

    const invoices = await Invoice.find({ groupId: { $in: groupIds } });
    const invoiceIds = invoices.map(i => i._id.toString());

    // Clean in order
    await InvoiceItem.deleteMany({ invoiceId: { $in: invoiceIds } });
    await OriginalDebt.deleteMany({ groupId: { $in: groupIds } });
    await Invoice.deleteMany({ groupId: { $in: groupIds } });
    await GroupMember.deleteMany({ groupId: { $in: groupIds } });
    await Group.deleteMany({ _id: { $in: groupIds } });

    // Also clean any transfers/payment requests
    const { Transfer } = await import('../src/models/Transfer');
    const { TransferDebtAllocation } = await import('../src/models/TransferDebtAllocation');
    const { PaymentRequest } = await import('../src/models/PaymentRequest');

    const paymentRequests = await PaymentRequest.find({ groupId: { $in: groupIds } });
    const prIds = paymentRequests.map(pr => pr._id.toString());
    const transfers = await Transfer.find({ groupId: { $in: groupIds } });
    const transferIds = transfers.map(t => t._id.toString());

    await TransferDebtAllocation.deleteMany({ transferId: { $in: transferIds } });
    await Transfer.deleteMany({ groupId: { $in: groupIds } });
    await PaymentRequest.deleteMany({ groupId: { $in: groupIds } });

    await User.deleteMany({ _id: { $in: userIds } });

    console.log(`✅ Cleaned: ${userIds.length} users, ${groupIds.length} groups, ${invoiceIds.length} invoices, ${transferIds.length} transfers, ${prIds.length} payment requests`);
}

async function seed() {
    console.log('🌱 Seeding test data for payment request flow...\n');

    // ── 1. Create 3 test users ──────────────────────────────────────
    const passwordHash = '$2b$$dummyHashForTestingPurposesOnly000000000000000'; // not a real hash

    const [userA, userB, userC] = await User.create([
        { email: 'test_a@splitpal.test', passwordHash, displayName: `${TEST_PREFIX}User_A`, status: 'active', balance: 1_000_000 },
        { email: 'test_b@splitpal.test', passwordHash, displayName: `${TEST_PREFIX}User_B`, status: 'active', balance: 1_000_000 },
        { email: 'test_c@splitpal.test', passwordHash, displayName: `${TEST_PREFIX}User_C`, status: 'active', balance: 1_000_000 },
    ]);

    const idA = userA._id.toString();
    const idB = userB._id.toString();
    const idC = userC._id.toString();

    console.log(`👤 User A: ${idA} (${userA.displayName})`);
    console.log(`👤 User B: ${idB} (${userB.displayName})`);
    console.log(`👤 User C: ${idC} (${userC.displayName})`);

    // ── 2. Create group ─────────────────────────────────────────────
    const [group] = await Group.create([{
        name: 'Test Payment Flow',
        baseCurrency: 'VND',
        createdBy: idA,
    }]);
    const groupId = group._id.toString();
    console.log(`\n🏠 Group: ${groupId} (${group.name})`);

    // ── 3. Add members ──────────────────────────────────────────────
    await GroupMember.create([
        { groupId, userId: idA, role: 'OWNER' },
        { groupId, userId: idB, role: 'USER' },
        { groupId, userId: idC, role: 'USER' },
    ]);
    console.log('👥 Members added: A (OWNER), B (USER), C (USER)');

    // ── 4. Create 3 invoices ────────────────────────────────────────
    //
    //   Invoice 1: A uploads, 300,000 VND total
    //     - Item "Dinner" 300,000 → assigned to [A, B, C] (100k each)
    //     → B owes A 100k, C owes A 100k
    //
    //   Invoice 2: B uploads, 150,000 VND total
    //     - Item "Taxi" 150,000 → assigned to [A, B, C] (50k each)
    //     → A owes B 50k, C owes B 50k
    //
    //   Invoice 3: C uploads, 210,000 VND total
    //     - Item "Groceries" 210,000 → assigned to [A, B, C] (70k each)
    //     → A owes C 70k, B owes C 70k

    const invoices = await Invoice.create([
        { groupId, title: 'Dinner (by A)', amountTotal: 300000, currency: 'VND', uploadedBy: idA, status: 'SUBMITTED' },
        { groupId, title: 'Taxi (by B)', amountTotal: 150000, currency: 'VND', uploadedBy: idB, status: 'SUBMITTED' },
        { groupId, title: 'Groceries (by C)', amountTotal: 210000, currency: 'VND', uploadedBy: idC, status: 'SUBMITTED' },
    ]);
    const inv1 = invoices[0]._id.toString();
    const inv2 = invoices[1]._id.toString();
    const inv3 = invoices[2]._id.toString();

    console.log(`\n🧾 Invoice 1: ${inv1} — Dinner 300k (by A, split A/B/C)`);
    console.log(`🧾 Invoice 2: ${inv2} — Taxi 150k (by B, split A/B/C)`);
    console.log(`🧾 Invoice 3: ${inv3} — Groceries 210k (by C, split A/B/C)`);

    // ── 5. Create invoice items ─────────────────────────────────────
    await InvoiceItem.create([
        { invoiceId: inv1, name: 'Dinner', amount: 300000, assignedTo: [idA, idB, idC] },
        { invoiceId: inv2, name: 'Taxi', amount: 150000, assignedTo: [idA, idB, idC] },
        { invoiceId: inv3, name: 'Groceries', amount: 210000, assignedTo: [idA, idB, idC] },
    ]);

    // ── 6. Create OriginalDebts ─────────────────────────────────────
    //   Invoice 1 (A paid): B→A 100k, C→A 100k
    //   Invoice 2 (B paid): A→B 50k, C→B 50k
    //   Invoice 3 (C paid): A→C 70k, B→C 70k
    //
    //   Net balances:
    //     A: +100k +100k -50k -70k = +80k (people owe A 80k)
    //     B: -100k +50k +50k -70k = -70k  (B owes 70k net)
    //     C: -100k -50k +70k +70k = -10k  (C owes 10k net)
    //
    //   After netting:
    //     B → A: 100k - 50k = 50k (net B owes A)
    //     C → A: 100k - 70k = 30k (net C owes A)
    //     C → B: 50k - 70k = C owes B nothing, B owes C 20k → net: B→C 20k
    //
    //   Optimal transfers (greedy):
    //     B → A: ~50k + some to offset B→C
    //     Actually let the algorithm figure it out from remaining debts

    await OriginalDebt.create([
        // From Invoice 1 (A paid)
        { groupId, invoiceId: inv1, debtorId: idB, creditorId: idA, originalAmount: 100000, remainingAmount: 100000 },
        { groupId, invoiceId: inv1, debtorId: idC, creditorId: idA, originalAmount: 100000, remainingAmount: 100000 },
        // From Invoice 2 (B paid)
        { groupId, invoiceId: inv2, debtorId: idA, creditorId: idB, originalAmount: 50000, remainingAmount: 50000 },
        { groupId, invoiceId: inv2, debtorId: idC, creditorId: idB, originalAmount: 50000, remainingAmount: 50000 },
        // From Invoice 3 (C paid)
        { groupId, invoiceId: inv3, debtorId: idA, creditorId: idC, originalAmount: 70000, remainingAmount: 70000 },
        { groupId, invoiceId: inv3, debtorId: idB, creditorId: idC, originalAmount: 70000, remainingAmount: 70000 },
    ]);

    // ── Summary ─────────────────────────────────────────────────────
    console.log('\n═══════════════════════════════════════════════════');
    console.log('📊 Debt Summary (before payment request):');
    console.log('───────────────────────────────────────────────────');
    console.log('  B → A: 100,000 VND (dinner)');
    console.log('  C → A: 100,000 VND (dinner)');
    console.log('  A → B:  50,000 VND (taxi)');
    console.log('  C → B:  50,000 VND (taxi)');
    console.log('  A → C:  70,000 VND (groceries)');
    console.log('  B → C:  70,000 VND (groceries)');
    console.log('───────────────────────────────────────────────────');
    console.log('  Net A: +80,000 (is owed)');
    console.log('  Net B: -70,000 (owes)');
    console.log('  Net C: -10,000 (owes)');
    console.log('═══════════════════════════════════════════════════');
    console.log('\n🧪 Test steps:');
    console.log(`  1. Login as User A (OWNER): test_a@splitpal.test`);
    console.log(`  2. Go to group "${group.name}" → Create Payment Request`);
    console.log('  3. Two optimized transfers should be created:');
    console.log('     B → A: ~70,000 (B\'s net debt)');
    console.log('     C → A: ~10,000 (C\'s net debt)');
    console.log('  4. Have B pay their transfer');
    console.log('  5. Have C cancel their transfer');
    console.log('     → Full cancel triggered: B gets refund, all debts restored');
    console.log('  6. Create new payment request → recalculates from scratch');
    console.log('═══════════════════════════════════════════════════\n');
}

async function main() {
    const isClean = process.argv.includes('--clean');

    try {
        console.log('Connecting to MongoDB...');
        await mongoose.connect(process.env.MONGODB_URI as string);
        console.log('Connected.\n');

        if (isClean) {
            await clean();
        } else {
            // Always clean first to avoid duplicates
            await clean();
            await seed();
        }
    } catch (error) {
        console.error('❌ Error:', error);
        process.exit(1);
    } finally {
        await mongoose.disconnect();
        console.log('Disconnected from MongoDB.');
    }
}

main();
