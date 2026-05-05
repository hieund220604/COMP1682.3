/**
 * seed-demo.ts
 * ─────────────────────────────────────────────────────────
 * Drops the ENTIRE database then recreates demo data.
 * Usage:  npm run seed:demo
 * ─────────────────────────────────────────────────────────
 */
import dotenv from 'dotenv';
dotenv.config();

import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';

/* ── DB connect ─────────────────────────────────────────── */
const connectDB = async () => {
    const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/splitpal';
    const tls = uri.includes('mongodb+srv') || uri.includes('tls=true');
    await mongoose.connect(uri, {
        serverSelectionTimeoutMS: 10_000,
        ...(tls ? { tls: true, tlsAllowInvalidCertificates: true, tlsAllowInvalidHostnames: true } : {}),
    });
    console.log(`✓ Connected to MongoDB (${mongoose.connection.name})`);
};

/* ── Helper: offset date from now ───────────────────────── */
const daysFromNow = (d: number) => new Date(Date.now() + d * 86_400_000);
const daysAgo = (d: number) => new Date(Date.now() - d * 86_400_000);
const hoursAgo = (h: number) => new Date(Date.now() - h * 3_600_000);

/* ── MAIN ───────────────────────────────────────────────── */
async function main() {
    await connectDB();

    // Dynamic imports
    const { User } = await import('../src/models/User');
    const { Group } = await import('../src/models/Group');
    const { GroupMember } = await import('../src/models/GroupMember');
    const { Subscription } = await import('../src/models/Subscription');
    const { SubscriptionMember } = await import('../src/models/SubscriptionMember');
    const { Invoice } = await import('../src/models/Invoice');
    const { InvoiceItem } = await import('../src/models/InvoiceItem');
    const { OriginalDebt } = await import('../src/models/OriginalDebt');
    const { BillTemplate } = await import('../src/models/BillTemplate');
    const { ReceiptTag } = await import('../src/models/ReceiptTag');
    const { Transaction } = await import('../src/models/Transaction');
    const { Notification, NotificationType } = await import('../src/models/Notification');
    const { BillingHistory } = await import('../src/models/BillingHistory');
    const { TopUp } = await import('../src/models/TopUp');

    // ═══════════════════════════════════════════════════════
    // STEP 0: DROP DATABASE
    // ═══════════════════════════════════════════════════════
    console.log('\n🗑️  Dropping entire database...');
    await mongoose.connection.dropDatabase();
    console.log('✓ Database dropped\n');

    // ═══════════════════════════════════════════════════════
    // STEP 1: USERS
    // ═══════════════════════════════════════════════════════
    console.log('── Step 1: Users ──');
    const passwordHash = await bcrypt.hash('Test@1234', 10);
    const usersData = [
        { email: 'test1@example.com', displayName: 'Test User 1', balance: 100_000_000, isPro: true },
        { email: 'test2@example.com', displayName: 'Test User 2', balance: 70_000_000, isPro: true },
        { email: 'test3@example.com', displayName: 'Test User 3', balance: 80_000_000, isPro: true },
        { email: 'test4@example.com', displayName: 'Test User 4', balance: 98_000_000, isPro: false },
        { email: 'test5@example.com', displayName: 'Test User 5', balance: 12_000_000, isPro: false },
    ];

    const users = [];
    for (const u of usersData) {
        const doc = await User.create({
            email: u.email,
            passwordHash,
            displayName: u.displayName,
            status: 'active',
            balance: u.balance,
            currency: 'VND',
            isPro: u.isPro,
        });
        users.push(doc);
        console.log(`  + ${u.email} (balance: ${u.balance.toLocaleString()})`);
    }
    const [u1, u2, u3, u4, u5] = users;
    const uid = (u: any) => u._id.toString();
    const allUids = users.map(uid);

    // ═══════════════════════════════════════════════════════
    // STEP 2: GROUP + MEMBERS
    // ═══════════════════════════════════════════════════════
    console.log('\n── Step 2: Group ──');
    const group = await Group.create({
        name: 'Test Group',
        description: 'Demo group for testing all features',
        baseCurrency: 'VND',
        timezone: 'Asia/Ho_Chi_Minh',
        joinCode: 'TEST01',
        createdBy: uid(u1),
    });
    console.log(`  + Group: ${group.name} (code: TEST01)`);

    const gid = group._id.toString();
    const roles: Array<'OWNER' | 'ADMIN' | 'USER'> = ['OWNER', 'ADMIN', 'ADMIN', 'USER', 'USER'];
    for (let i = 0; i < users.length; i++) {
        await GroupMember.create({ groupId: gid, userId: uid(users[i]), role: roles[i] });
        console.log(`  + Member: ${users[i].displayName} → ${roles[i]}`);
    }

    // ═══════════════════════════════════════════════════════
    // STEP 3: SUBSCRIPTIONS
    // ═══════════════════════════════════════════════════════
    console.log('\n── Step 3: Subscriptions ──');
    const subsData = [
        { name: 'Test Subs 1', amount: 100_000, createdBy: u1 },
        { name: 'Test Subs 2', amount: 150_000, createdBy: u2 },
        { name: 'Test Subs 3', amount: 50_000, createdBy: u3 },
        { name: 'Test Subs 4', amount: 75_000, createdBy: u4 },
        { name: 'Test Subs 5', amount: 10_000, createdBy: u5 },
        { name: 'Test Subs 6', amount: 35_000, createdBy: u1 },
        { name: 'Test Subs 7', amount: 40_000, createdBy: u1 },
    ];

    const subs = [];
    for (const s of subsData) {
        const sub = await Subscription.create({
            groupId: gid,
            name: s.name,
            description: `Subscription: ${s.name}`,
            amount: s.amount,
            currency: 'VND',
            billingCycle: 'DAILY',
            status: 'ACTIVE',
            createdBy: uid(s.createdBy),
        });
        subs.push(sub);

        // Create members with staggered nextBillingDate
        for (let i = 0; i < users.length; i++) {
            const now = new Date();
            const joinedAt = daysAgo(5 - i); // staggered join
            const nextBilling = daysFromNow(i); // staggered billing
            await SubscriptionMember.create({
                subscriptionId: sub._id.toString(),
                userId: uid(users[i]),
                amount: s.amount,
                status: 'ACTIVE',
                joinedAt,
                nextBillingDate: nextBilling,
                lastChargedAt: joinedAt,
                retryCount: 0,
            });
        }
        console.log(`  + ${s.name}: ${s.amount.toLocaleString()}đ/mem (owner: ${s.createdBy.displayName})`);
    }

    // ═══════════════════════════════════════════════════════
    // STEP 4: INVOICES (15)
    // ═══════════════════════════════════════════════════════
    console.log('\n── Step 4: Invoices (15) ──');
    const invoicesData = [
        // 10 VND invoices
        { title: 'Tiền ăn trưa', currency: 'VND', amount: 500_000, by: u1 },
        { title: 'Tiền điện tháng 5', currency: 'VND', amount: 1_200_000, by: u2 },
        { title: 'Tiền nước tháng 5', currency: 'VND', amount: 350_000, by: u3 },
        { title: 'Mua đồ siêu thị', currency: 'VND', amount: 780_000, by: u4 },
        { title: 'Tiền internet', currency: 'VND', amount: 450_000, by: u1 },
        { title: 'Ăn tối nhà hàng', currency: 'VND', amount: 2_500_000, by: u2 },
        { title: 'Vé xem phim', currency: 'VND', amount: 600_000, by: u3 },
        { title: 'Đặt xe Grab', currency: 'VND', amount: 320_000, by: u5 },
        { title: 'Mua sách', currency: 'VND', amount: 250_000, by: u1 },
        { title: 'Tiền gas', currency: 'VND', amount: 180_000, by: u4 },
        // 5 foreign currency invoices
        { title: 'Amazon order', currency: 'USD', amount: 45, by: u1, rate: 25_400, converted: 1_143_000 },
        { title: 'Netflix subscription', currency: 'USD', amount: 15.99, by: u2, rate: 25_400, converted: 406_146 },
        { title: 'Sushi dinner', currency: 'JPY', amount: 8_500, by: u3, rate: 170, converted: 1_445_000 },
        { title: 'Museum tickets', currency: 'EUR', amount: 32, by: u1, rate: 27_800, converted: 889_600 },
        { title: 'Cafe in London', currency: 'GBP', amount: 24.5, by: u5, rate: 32_500, converted: 796_250 },
    ];

    for (let idx = 0; idx < invoicesData.length; idx++) {
        const inv = invoicesData[idx];
        const isForeign = inv.currency !== 'VND';
        const amountInBase = isForeign ? inv.converted! : inv.amount;

        const invoiceDoc = new Invoice({
            groupId: gid,
            title: inv.title,
            amountTotal: inv.amount,
            currency: inv.currency,
            uploadedBy: uid(inv.by),
            invoiceDate: daysAgo(14 - idx), // spread over 2 weeks
            status: 'SUBMITTED',
            ...(isForeign ? {
                convertedAmountTotal: inv.converted,
                exchangeRate: inv.rate,
                baseCurrency: 'VND',
            } : {}),
        });
        invoiceDoc.set('templateId', undefined);
        invoiceDoc.set('billingPeriod', undefined);
        await invoiceDoc.save();

        const invId = invoiceDoc._id.toString();

        // Create 2 items per invoice
        const item1Amount = Math.round(inv.amount * 0.6);
        const item2Amount = inv.amount - item1Amount;
        await InvoiceItem.create({
            invoiceId: invId,
            name: `${inv.title} - Phần 1`,
            amount: item1Amount,
            splitType: 'EQUAL',
            assignedTo: allUids,
            splits: [],
        });
        await InvoiceItem.create({
            invoiceId: invId,
            name: `${inv.title} - Phần 2`,
            amount: item2Amount,
            splitType: 'EQUAL',
            assignedTo: allUids,
            splits: [],
        });

        // Create OriginalDebt records (each non-uploader owes uploader)
        const perPerson = Math.round(amountInBase / 5);
        for (const member of users) {
            if (uid(member) === uid(inv.by)) continue;
            await OriginalDebt.create({
                groupId: gid,
                invoiceId: invId,
                debtorId: uid(member),
                creditorId: uid(inv.by),
                originalAmount: perPerson,
                remainingAmount: perPerson,
                ...(isForeign ? {
                    originalCurrency: inv.currency,
                    originalAmountInCurrency: Math.round((inv.amount / 5) * 100) / 100,
                    exchangeRateUsed: inv.rate,
                    rateLockedAt: new Date(),
                } : {}),
            });
        }
        console.log(`  + #${idx + 1} ${inv.title} (${inv.currency} ${inv.amount.toLocaleString()})`);
    }

    // ═══════════════════════════════════════════════════════
    // STEP 5: BILL TEMPLATE
    // ═══════════════════════════════════════════════════════
    console.log('\n── Step 5: BillTemplate ──');
    await BillTemplate.create({
        groupId: gid,
        name: 'Tiền phòng hàng ngày',
        description: 'Chi phí phòng chia đều cho tất cả thành viên',
        billingCycle: 'DAILY',
        currency: 'VND',
        items: [{
            name: 'Tiền phòng',
            amount: 200_000,
            splitType: 'EQUAL',
            assignedTo: allUids,
            splits: [],
        }],
        payerId: uid(u1),
        status: 'ACTIVE',
        createdBy: uid(u1),
        nextBillDate: daysFromNow(1),
    });
    console.log('  + Tiền phòng hàng ngày (DAILY, 200,000đ, owner: Test User 1)');

    // ═══════════════════════════════════════════════════════
    // STEP 6: RECEIPT TAGS (for User 1)
    // ═══════════════════════════════════════════════════════
    console.log('\n── Step 6: ReceiptTags ──');
    const tagsData = [
        { name: 'ăn uống', color: '#FF6B6B', monthlyBudget: 5_000_000, icon: 'restaurant' },
        { name: 'di chuyển', color: '#4ECDC4', monthlyBudget: 2_000_000, icon: 'directions_car' },
        { name: 'giải trí', color: '#45B7D1', monthlyBudget: 3_000_000, icon: 'movie' },
        { name: 'hóa đơn', color: '#96CEB4', monthlyBudget: 4_000_000, icon: 'receipt_long' },
        { name: 'mua sắm', color: '#FFEAA7', monthlyBudget: 2_500_000, icon: 'shopping_bag' },
    ];
    const tags = [];
    for (const t of tagsData) {
        const tag = await ReceiptTag.create({ userId: uid(u1), ...t, isArchived: false });
        tags.push(tag);
        console.log(`  + ${t.name} (budget: ${t.monthlyBudget!.toLocaleString()}đ)`);
    }

    // ═══════════════════════════════════════════════════════
    // STEP 7: TRANSACTIONS
    // ═══════════════════════════════════════════════════════
    console.log('\n── Step 7: Transactions ──');
    const txData: Array<{
        userId: string; type: string; amount: number;
        balanceBefore: number; balanceAfter: number; desc: string; ago: number;
    }> = [
        { userId: uid(u1), type: 'TOP_UP', amount: 50_000_000, balanceBefore: 50_000_000, balanceAfter: 100_000_000, desc: 'Nạp tiền qua VNPay', ago: 10 },
        { userId: uid(u1), type: 'EXPENSE_PAYMENT', amount: -500_000, balanceBefore: 100_000_000, balanceAfter: 99_500_000, desc: 'Thanh toán: Tiền ăn trưa', ago: 9 },
        { userId: uid(u1), type: 'SUBSCRIPTION_FEE', amount: -100_000, balanceBefore: 99_500_000, balanceAfter: 99_400_000, desc: 'Phí sub: Test Subs 1', ago: 8 },
        { userId: uid(u2), type: 'TOP_UP', amount: 30_000_000, balanceBefore: 40_000_000, balanceAfter: 70_000_000, desc: 'Nạp tiền qua VNPay', ago: 10 },
        { userId: uid(u2), type: 'EXPENSE_PAYMENT', amount: -1_200_000, balanceBefore: 70_000_000, balanceAfter: 68_800_000, desc: 'Thanh toán: Tiền điện tháng 5', ago: 7 },
        { userId: uid(u2), type: 'SUBSCRIPTION_FEE', amount: -150_000, balanceBefore: 68_800_000, balanceAfter: 68_650_000, desc: 'Phí sub: Test Subs 2', ago: 6 },
        { userId: uid(u3), type: 'TOP_UP', amount: 80_000_000, balanceBefore: 0, balanceAfter: 80_000_000, desc: 'Nạp tiền qua VNPay', ago: 12 },
        { userId: uid(u3), type: 'EXPENSE_PAYMENT', amount: -350_000, balanceBefore: 80_000_000, balanceAfter: 79_650_000, desc: 'Thanh toán: Tiền nước tháng 5', ago: 5 },
        { userId: uid(u4), type: 'TOP_UP', amount: 100_000_000, balanceBefore: 0, balanceAfter: 100_000_000, desc: 'Nạp tiền qua VNPay', ago: 14 },
        { userId: uid(u4), type: 'EXPENSE_PAYMENT', amount: -780_000, balanceBefore: 100_000_000, balanceAfter: 99_220_000, desc: 'Thanh toán: Mua đồ siêu thị', ago: 4 },
        { userId: uid(u5), type: 'TOP_UP', amount: 15_000_000, balanceBefore: 0, balanceAfter: 15_000_000, desc: 'Nạp tiền qua VNPay', ago: 13 },
        { userId: uid(u5), type: 'EXPENSE_PAYMENT', amount: -320_000, balanceBefore: 15_000_000, balanceAfter: 14_680_000, desc: 'Thanh toán: Đặt xe Grab', ago: 3 },
        { userId: uid(u1), type: 'SUBSCRIPTION_FEE', amount: -35_000, balanceBefore: 99_400_000, balanceAfter: 99_365_000, desc: 'Phí sub: Test Subs 6', ago: 2 },
        { userId: uid(u1), type: 'SUBSCRIPTION_FEE', amount: -40_000, balanceBefore: 99_365_000, balanceAfter: 99_325_000, desc: 'Phí sub: Test Subs 7', ago: 1 },
    ];

    for (const tx of txData) {
        await Transaction.create({
            userId: tx.userId,
            type: tx.type,
            amount: tx.amount,
            balanceBefore: tx.balanceBefore,
            balanceAfter: tx.balanceAfter,
            currency: 'VND',
            description: tx.desc,
            createdAt: daysAgo(tx.ago),
        });
    }
    console.log(`  + ${txData.length} transactions created`);

    // ═══════════════════════════════════════════════════════
    // STEP 8: NOTIFICATIONS
    // ═══════════════════════════════════════════════════════
    console.log('\n── Step 8: Notifications ──');
    const notiData = [
        { userId: uid(u1), type: NotificationType.INVOICE_CREATED, title: 'Hóa đơn mới', message: 'Test User 2 đã tạo hóa đơn "Tiền điện tháng 5"', read: false, ago: 1 },
        { userId: uid(u1), type: NotificationType.SUBSCRIPTION_BILLING_SUCCESS, title: 'Thanh toán thành công', message: 'Phí subscription "Test Subs 1" đã được trừ: 100,000đ', read: true, ago: 2 },
        { userId: uid(u1), type: NotificationType.GROUP_JOINED, title: 'Thành viên mới', message: 'Test User 5 đã tham gia nhóm "Test Group"', read: true, ago: 5 },
        { userId: uid(u2), type: NotificationType.INVOICE_CREATED, title: 'Hóa đơn mới', message: 'Test User 1 đã tạo hóa đơn "Tiền ăn trưa"', read: false, ago: 1 },
        { userId: uid(u2), type: NotificationType.BALANCE_UPDATED, title: 'Số dư thay đổi', message: 'Số dư của bạn đã thay đổi: -150,000đ (Phí sub Test Subs 2)', read: false, ago: 3 },
        { userId: uid(u3), type: NotificationType.EXPENSE_CREATED, title: 'Chi phí mới', message: 'Bạn được gán vào hóa đơn "Mua đồ siêu thị" (156,000đ)', read: false, ago: 2 },
        { userId: uid(u3), type: NotificationType.RECURRING_BILL_DRAFT, title: 'Hóa đơn định kỳ', message: 'Hóa đơn "Tiền phòng hàng ngày" đã được tạo tự động', read: true, ago: 1 },
        { userId: uid(u4), type: NotificationType.INVOICE_CREATED, title: 'Hóa đơn mới', message: 'Test User 3 đã tạo hóa đơn "Vé xem phim"', read: false, ago: 4 },
        { userId: uid(u4), type: NotificationType.SUBSCRIPTION_BILLING_SUCCESS, title: 'Thanh toán sub', message: 'Phí subscription "Test Subs 4" đã được trừ: 75,000đ', read: true, ago: 6 },
        { userId: uid(u5), type: NotificationType.INVOICE_CREATED, title: 'Hóa đơn mới', message: 'Test User 1 đã tạo hóa đơn "Mua sách"', read: false, ago: 2 },
    ];

    for (const n of notiData) {
        await Notification.create({
            userId: n.userId,
            type: n.type,
            title: n.title,
            message: n.message,
            read: n.read,
            sentEmail: false,
            createdAt: daysAgo(n.ago),
        });
    }
    console.log(`  + ${notiData.length} notifications created`);

    // ═══════════════════════════════════════════════════════
    // STEP 9: BILLING HISTORY
    // ═══════════════════════════════════════════════════════
    console.log('\n── Step 9: BillingHistory ──');
    const sub1Id = subs[0]._id.toString();
    const sub2Id = subs[1]._id.toString();

    const billingData = [
        {
            subscriptionId: sub1Id, groupId: gid, billingDate: daysAgo(3),
            amount: 100_000, status: 'SUCCESS' as const, membersCharged: 5, membersFailed: 0,
            totalCollected: 500_000,
            memberResults: users.map(u => ({ userId: uid(u), shareAmount: 100_000, success: true })),
        },
        {
            subscriptionId: sub1Id, groupId: gid, billingDate: daysAgo(2),
            amount: 100_000, status: 'SUCCESS' as const, membersCharged: 5, membersFailed: 0,
            totalCollected: 500_000,
            memberResults: users.map(u => ({ userId: uid(u), shareAmount: 100_000, success: true })),
        },
        {
            subscriptionId: sub2Id, groupId: gid, billingDate: daysAgo(1),
            amount: 150_000, status: 'PARTIAL' as const, membersCharged: 4, membersFailed: 1,
            totalCollected: 600_000,
            memberResults: [
                ...users.slice(0, 4).map(u => ({ userId: uid(u), shareAmount: 150_000, success: true })),
                { userId: uid(u5), shareAmount: 150_000, success: false, reason: 'Insufficient balance' },
            ],
        },
    ];

    for (const bh of billingData) {
        await BillingHistory.create({ ...bh, currency: 'VND' });
    }
    console.log(`  + ${billingData.length} billing history records`);

    // ═══════════════════════════════════════════════════════
    // STEP 10: TOP UPS
    // ═══════════════════════════════════════════════════════
    console.log('\n── Step 10: TopUps ──');
    const topUps = [
        { userId: uid(u1), amount: 50_000_000, status: 'COMPLETED' as const, ago: 10 },
        { userId: uid(u2), amount: 30_000_000, status: 'COMPLETED' as const, ago: 10 },
        { userId: uid(u3), amount: 80_000_000, status: 'COMPLETED' as const, ago: 12 },
        { userId: uid(u4), amount: 100_000_000, status: 'COMPLETED' as const, ago: 14 },
        { userId: uid(u5), amount: 15_000_000, status: 'COMPLETED' as const, ago: 13 },
    ];

    for (const t of topUps) {
        await TopUp.create({
            userId: t.userId,
            amount: t.amount,
            status: t.status,
            createdAt: daysAgo(t.ago),
        });
    }
    console.log(`  + ${topUps.length} top-up records`);

    // ═══════════════════════════════════════════════════════
    // SUMMARY
    // ═══════════════════════════════════════════════════════
    console.log('\n═══════════════════════════════════════════');
    console.log('✅ SEED COMPLETE');
    console.log('═══════════════════════════════════════════');
    console.log(`  👤 Users:          ${users.length}`);
    console.log(`  👥 Group:          1 (Test Group)`);
    console.log(`  📦 Subscriptions:  ${subs.length}`);
    console.log(`  🧾 Invoices:       15 (10 VND + 5 foreign)`);
    console.log(`  📋 BillTemplates:  1`);
    console.log(`  🏷️  ReceiptTags:    ${tags.length}`);
    console.log(`  💳 Transactions:   ${txData.length}`);
    console.log(`  🔔 Notifications:  ${notiData.length}`);
    console.log(`  📊 BillingHistory: ${billingData.length}`);
    console.log(`  💰 TopUps:         ${topUps.length}`);
    console.log('═══════════════════════════════════════════');
    console.log('\n🔑 Login credentials:');
    for (const u of usersData) {
        console.log(`   ${u.email} / Test@1234`);
    }

    await mongoose.disconnect();
    console.log('\n✓ Disconnected. Done!');
}

main().catch(err => {
    console.error('❌ Seed failed:', err);
    process.exit(1);
});
