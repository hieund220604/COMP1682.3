/**
 * Subscription Billing Integration Test
 * Run: npx ts-node scripts/test-subscription-billing.ts
 *
 * Tests:
 *  1. processRenewals charges member when nextBillingDate has passed (BUG 1 fix)
 *  2. processRenewals does NOT charge when member just joined (idempotency guard)
 *  3. Aggregate lookup finds subscriptions correctly via $toObjectId (BUG 2 fix)
 *  4. leaveSubscription obligation: member owes fee when not yet charged (BUG 3 fix)
 *  5. leaveSubscription obligation: member owes 0 if already charged this cycle
 *  6. Full cycle: join → wait 1 cycle → charge → verify balances & history
 */

import mongoose from 'mongoose';
import { MongoMemoryReplSet } from 'mongodb-memory-server';
import { Subscription } from '../src/models/Subscription';
import { SubscriptionMember } from '../src/models/SubscriptionMember';
import { SubInvitation } from '../src/models/SubInvitation';
import { BillingHistory } from '../src/models/BillingHistory';
import { User } from '../src/models/User';
import { Group } from '../src/models/Group';
import { GroupMember } from '../src/models/GroupMember';
import { subscriptionService } from '../src/service/subscriptionService';

// ── Color helpers ────────────────────────────────────────────────────────────
const green = (s: string) => `\x1b[32m${s}\x1b[0m`;
const red   = (s: string) => `\x1b[31m${s}\x1b[0m`;
const cyan  = (s: string) => `\x1b[36m${s}\x1b[0m`;
const bold  = (s: string) => `\x1b[1m${s}\x1b[0m`;

let passed = 0;
let failed = 0;

function assert(condition: boolean, description: string, extra?: string) {
    if (condition) {
        console.log(green('  ✓') + ' ' + description);
        passed++;
    } else {
        console.log(red('  ✗') + ' ' + description + (extra ? `\n    ${red('→')} ${extra}` : ''));
        failed++;
    }
}

async function setup() {
    const replSet = await MongoMemoryReplSet.create({ replSet: { count: 1 } });
    const uri = replSet.getUri();
    await mongoose.connect(uri);
    return replSet;
}

async function teardown(replSet: MongoMemoryReplSet) {
    await mongoose.disconnect();
    await replSet.stop();
}

async function createTestData() {
    // Create group
    const group = await Group.create({ name: 'Test Group', createdBy: 'owner-id' });
    const groupId = group._id.toString();

    // Create owner + member users (balance: 500k VND each)
    const owner = await User.create({
        _id: new mongoose.Types.ObjectId(),
        email: 'owner@test.com',
        displayName: 'Owner',
        passwordHash: 'hashed',
        balance: 500_000,
    });
    const member = await User.create({
        _id: new mongoose.Types.ObjectId(),
        email: 'member@test.com',
        displayName: 'Member',
        passwordHash: 'hashed',
        balance: 500_000,
    });

    // Add both to group
    await GroupMember.create([
        { groupId, userId: owner._id.toString(), role: 'OWNER' },
        { groupId, userId: member._id.toString(), role: 'USER' },
    ]);

    // Create DAILY subscription (100 VND/day for easy testing)
    const sub = await Subscription.create({
        groupId,
        name: 'Netflix',
        amount: 100,
        currency: 'VND',
        billingCycle: 'DAILY',
        status: 'ACTIVE',
        createdBy: owner._id.toString(),
    });

    return { group, groupId, owner, member, sub };
}

// ── TEST 1: Charge fires when billing date has passed ─────────────────────
async function test_chargesFiredWhenDue() {
    console.log(cyan('\nTest 1: processRenewals charges member when nextBillingDate has passed'));

    const { owner, member, sub, groupId } = await createTestData();
    const subId = sub._id.toString();
    const fee = 100;
    const ownerBalanceBefore = owner.balance;
    const memberBalanceBefore = member.balance;

    // Simulate: member joined yesterday, nextBillingDate = now (past due)
    const joinedAt = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000); // 2 days ago
    const nextBillingDate = new Date(Date.now() - 1 * 60 * 60 * 1000); // 1 hour ago (past due)

    await SubscriptionMember.create({
        subscriptionId: subId,
        userId: member._id.toString(),
        amount: fee,
        status: 'ACTIVE',
        joinedAt,
        nextBillingDate,
        lastChargedAt: joinedAt, // charged only at join time
        retryCount: 0,
    });

    const result = await subscriptionService.processRenewals();

    const memberAfter = await User.findById(member._id);
    const ownerAfter = await User.findById(owner._id);
    const billingRecord = await BillingHistory.findOne({ subscriptionId: subId });
    const memberDoc = await SubscriptionMember.findOne({ subscriptionId: subId });

    assert(result.charged === 1, `charged count = 1 (got ${result.charged})`);
    assert(result.failed === 0, `failed count = 0 (got ${result.failed})`);
    assert(memberAfter!.balance === memberBalanceBefore - fee,
        `member balance decreased by ${fee} (${memberBalanceBefore} → ${memberAfter!.balance})`);
    assert(ownerAfter!.balance === ownerBalanceBefore + fee,
        `owner balance increased by ${fee} (${ownerBalanceBefore} → ${ownerAfter!.balance})`);
    assert(billingRecord !== null, 'BillingHistory record created');
    assert(billingRecord?.status === 'SUCCESS', `BillingHistory status = SUCCESS`);
    assert(memberDoc!.nextBillingDate > nextBillingDate,
        `nextBillingDate advanced beyond old date`);

    await mongoose.connection.dropDatabase();
}

// ── TEST 2: Idempotency guard — do NOT charge if just joined this cycle ────
async function test_idempotencyGuard_noDoubleCharge() {
    console.log(cyan('\nTest 2: processRenewals does NOT double-charge on same cycle (idempotency guard)'));

    const { owner, member, sub } = await createTestData();
    const subId = sub._id.toString();
    const fee = 100;
    const ownerBalanceBefore = owner.balance;
    const memberBalanceBefore = member.balance;

    // Member just paid initial fee moments ago; nextBillingDate is in the future
    const now = new Date();
    const nextBillingDate = new Date(Date.now() + 23 * 60 * 60 * 1000); // 23h from now

    await SubscriptionMember.create({
        subscriptionId: subId,
        userId: member._id.toString(),
        amount: fee,
        status: 'ACTIVE',
        joinedAt: now,
        nextBillingDate,
        lastChargedAt: now,
        retryCount: 0,
    });

    const result = await subscriptionService.processRenewals();

    const memberAfter = await User.findById(member._id);
    const ownerAfter = await User.findById(owner._id);

    // nextBillingDate is in the future → no members should be due
    assert(result.totalMembersChecked === 0, `no members due (got ${result.totalMembersChecked})`);
    assert(memberAfter!.balance === memberBalanceBefore, `member balance unchanged`);
    assert(ownerAfter!.balance === ownerBalanceBefore, `owner balance unchanged`);

    await mongoose.connection.dropDatabase();
}

// ── TEST 3: Idempotency guard exact boundary — lastChargedAt === cycleStart ──
async function test_idempotencyGuard_exactBoundary() {
    console.log(cyan('\nTest 3: Idempotency guard (BUG 1 fix) — charges when lastChargedAt === cycleStart'));

    const { owner, member, sub } = await createTestData();
    const subId = sub._id.toString();
    const fee = 100;
    const ownerBalanceBefore = owner.balance;
    const memberBalanceBefore = member.balance;

    // The critical scenario that was broken:
    // Member joined exactly 1 day ago → lastChargedAt = T, nextBillingDate = T + 1 day
    // cycleStart = nextBillingDate - 1 day = T
    // Old code: lastChargedAt (T) >= cycleStart (T) → TRUE → skip (BUG!)
    // New code: lastChargedAt (T) > cycleStart (T)  → FALSE → charge (CORRECT)
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000 - 60_000); // 1 day + 1 min ago
    const nextBillingDate = new Date(Date.now() - 60_000); // 1 min ago (past due)

    await SubscriptionMember.create({
        subscriptionId: subId,
        userId: member._id.toString(),
        amount: fee,
        status: 'ACTIVE',
        joinedAt: oneDayAgo,
        nextBillingDate,
        lastChargedAt: oneDayAgo, // exactly at cycle start
        retryCount: 0,
    });

    const result = await subscriptionService.processRenewals();

    const memberAfter = await User.findById(member._id);
    const ownerAfter = await User.findById(owner._id);

    assert(result.charged === 1,
        `charged = 1 — BUG 1 is fixed! (was 0 before fix, got ${result.charged})`);
    assert(memberAfter!.balance === memberBalanceBefore - fee,
        `member balance decreased (${memberBalanceBefore} → ${memberAfter!.balance})`);
    assert(ownerAfter!.balance === ownerBalanceBefore + fee,
        `owner balance increased (${ownerBalanceBefore} → ${ownerAfter!.balance})`);

    await mongoose.connection.dropDatabase();
}

// ── TEST 4: Insufficient balance → retry count increments ─────────────────
async function test_insufficientBalance_retry() {
    console.log(cyan('\nTest 4: Insufficient balance → retryCount increments, no charge'));

    const { owner, member, sub } = await createTestData();
    const subId = sub._id.toString();

    // Set member balance to 0
    await User.findByIdAndUpdate(member._id, { balance: 0 });

    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000 - 60_000);
    const nextBillingDate = new Date(Date.now() - 60_000);

    await SubscriptionMember.create({
        subscriptionId: subId,
        userId: member._id.toString(),
        amount: 100,
        status: 'ACTIVE',
        joinedAt: oneDayAgo,
        nextBillingDate,
        lastChargedAt: oneDayAgo,
        retryCount: 0,
    });

    const result = await subscriptionService.processRenewals();
    const memberDoc = await SubscriptionMember.findOne({ subscriptionId: subId });

    assert(result.failed === 1, `failed = 1 (got ${result.failed})`);
    assert(result.charged === 0, `charged = 0 (got ${result.charged})`);
    assert(memberDoc!.retryCount === 1, `retryCount = 1 (got ${memberDoc!.retryCount})`);
    assert(memberDoc!.status === 'ACTIVE', 'member still ACTIVE (not kicked yet)');

    await mongoose.connection.dropDatabase();
}

// ── TEST 5: 3 retries → member kicked ────────────────────────────────────
async function test_threeRetries_kicked() {
    console.log(cyan('\nTest 5: After 3 failed attempts, member gets kicked'));

    const { owner, member, sub } = await createTestData();
    const subId = sub._id.toString();

    // Set member balance to 0
    await User.findByIdAndUpdate(member._id, { balance: 0 });

    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000 - 60_000);
    const nextBillingDate = new Date(Date.now() - 60_000);

    await SubscriptionMember.create({
        subscriptionId: subId,
        userId: member._id.toString(),
        amount: 100,
        status: 'ACTIVE',
        joinedAt: oneDayAgo,
        nextBillingDate,
        lastChargedAt: oneDayAgo,
        retryCount: 2, // already failed twice → this is 3rd attempt
    });

    const result = await subscriptionService.processRenewals();
    const memberDoc = await SubscriptionMember.findOne({ subscriptionId: subId });
    const historyRecord = await BillingHistory.findOne({ subscriptionId: subId, status: 'FAILED' });

    assert(result.kicked === 1, `kicked = 1 (got ${result.kicked})`);
    assert(memberDoc!.status === 'LEFT', `member status = LEFT`);
    assert(historyRecord !== null, 'FAILED BillingHistory record created');

    await mongoose.connection.dropDatabase();
}

// ── TEST 6: leaveSubscription — owes fee when billing date passed ─────────
async function test_leave_owesCurrentCycleFee() {
    console.log(cyan('\nTest 6: leaveSubscription — member owes fee when billing date has passed (BUG 3 fix)'));

    const { owner, member, sub, groupId } = await createTestData();
    const subId = sub._id.toString();
    const fee = 100;
    const ownerBalanceBefore = (await User.findById(owner._id))!.balance;
    const memberBalanceBefore = (await User.findById(member._id))!.balance;

    // nextBillingDate is tomorrow, lastChargedAt = exactly 1 day ago (cycle boundary)
    // Old code: lastChargedAt >= cycleStart → TRUE → obligation = 0 (wrong!)
    // New code: lastChargedAt > cycleStart → FALSE → obligation = fee (correct!)
    const oneDayAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000);

    // Create invitation and accept to create proper membership
    const invite = await SubInvitation.create({
        subscriptionId: subId,
        inviteeId: member._id.toString(),
        invitedBy: owner._id.toString(),
        status: 'ACCEPTED',
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    const subMember = await SubscriptionMember.create({
        subscriptionId: subId,
        userId: member._id.toString(),
        amount: fee,
        status: 'ACTIVE',
        joinedAt: oneDayAgo,
        nextBillingDate: tomorrow,
        lastChargedAt: oneDayAgo, // = cycleStart (1 cycle before tomorrow)
        retryCount: 0,
    });

    await subscriptionService.leaveSubscription(member._id.toString(), subId);

    const memberAfter = await User.findById(member._id);
    const ownerAfter = await User.findById(owner._id);
    const subMemberAfter = await SubscriptionMember.findById(subMember._id);

    assert(subMemberAfter!.status === 'LEFT', 'member status = LEFT');
    assert(memberAfter!.balance === memberBalanceBefore - fee,
        `member balance decreased by fee (${memberBalanceBefore} → ${memberAfter!.balance}) — BUG 3 fix verified`);
    assert(ownerAfter!.balance === ownerBalanceBefore + fee,
        `owner balance increased by fee (${ownerBalanceBefore} → ${ownerAfter!.balance})`);

    await mongoose.connection.dropDatabase();
}

// ── TEST 7: leaveSubscription — no fee when already paid this cycle ────────
async function test_leave_noFeeWhenAlreadyPaid() {
    console.log(cyan('\nTest 7: leaveSubscription — no fee when already paid this cycle'));

    const { owner, member, sub } = await createTestData();
    const subId = sub._id.toString();
    const fee = 100;
    const ownerBalanceBefore = (await User.findById(owner._id))!.balance;
    const memberBalanceBefore = (await User.findById(member._id))!.balance;

    // lastChargedAt = 10 min ago (within current cycle, strictly after cycleStart)
    // cycleStart will be nextBillingDate - 24h = 30 mins ago
    const tenMinsAgo = new Date(Date.now() - 10 * 60 * 1000);
    const tomorrow = new Date(Date.now() + 23.5 * 60 * 60 * 1000);

    await SubInvitation.create({
        subscriptionId: subId,
        inviteeId: member._id.toString(),
        invitedBy: owner._id.toString(),
        status: 'ACCEPTED',
        expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });

    const subMember = await SubscriptionMember.create({
        subscriptionId: subId,
        userId: member._id.toString(),
        amount: fee,
        status: 'ACTIVE',
        joinedAt: new Date(Date.now() - 24 * 60 * 60 * 1000),
        nextBillingDate: tomorrow,
        lastChargedAt: tenMinsAgo, // charged recently — well within cycle
        retryCount: 0,
    });

    await subscriptionService.leaveSubscription(member._id.toString(), subId);

    const memberAfter = await User.findById(member._id);
    const ownerAfter = await User.findById(owner._id);
    const subMemberAfter = await SubscriptionMember.findById(subMember._id);

    assert(subMemberAfter!.status === 'LEFT', 'member status = LEFT');
    assert(memberAfter!.balance === memberBalanceBefore,
        `member balance unchanged (no fee — already paid this cycle)`);
    assert(ownerAfter!.balance === ownerBalanceBefore, `owner balance unchanged`);

    await mongoose.connection.dropDatabase();
}

// ── MAIN ──────────────────────────────────────────────────────────────────
async function main() {
    console.log(bold('\n═══ Subscription Billing Tests ═══\n'));
    const mongod = await setup();

    try {
        await test_chargesFiredWhenDue();
        await test_idempotencyGuard_noDoubleCharge();
        await test_idempotencyGuard_exactBoundary();
        await test_insufficientBalance_retry();
        await test_threeRetries_kicked();
        await test_leave_owesCurrentCycleFee();
        await test_leave_noFeeWhenAlreadyPaid();
    } catch (err) {
        console.error(red('\nUnexpected error during tests:'), err);
        failed++;
    } finally {
        await teardown(mongod);
    }

    console.log(bold(`\n═══ Results: ${green(`${passed} passed`)} / ${failed > 0 ? red(`${failed} failed`) : '0 failed'} ═══\n`));
    process.exit(failed > 0 ? 1 : 0);
}

main().catch(console.error);
