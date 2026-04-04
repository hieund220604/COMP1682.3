# SplitPal - Detailed Collection Analysis
## Ý Nghĩa & Vai Trò Của Từng Collection Trong Hệ Thống

---

## 1. **users** - Nền tảng của toàn bộ hệ thống

### Ý nghĩa
- **Core Entity:** Lưu thông tin tất cả người dùng trong hệ thống
- **Wallet Hub:** Mỗi user có `balance` = ví digital cá nhân

### Vai trò chính
```
┌─────────────────────────────────────────────────────────────┐
│                         USER RECORD                         │
│─────────────────────────────────────────────────────────────│
│ • Email + Password → Authentication                         │
│ • balance → Wallet (how much money they have to spend)     │
│ • currency → Default currency (VND)                         │
│ • 2FA fields → Security (twoFactorSecret, backup codes)    │
│ • FCM token → Push notifications                            │
│ • status → Active/Inactive (for soft delete)               │
└─────────────────────────────────────────────────────────────┘

Flow:
1. User registers → Create record with password hash
2. User logs in → Authenticate + load balance
3. User top-ups → balance increases (transaction log created)
4. User pays transfer → balance decreases (transaction log created)
```

### Ví dụ thực tế
```
User: Nguyễn Văn A (nvana@gmail.com)
- balance: 1,500,000 VND (ví của A)
- Có thể join nhiều groups
- Có thể receive transfers từ users khác
- Mỗi giao dịch đều track history bằng transactions collection
```

### Tại sao cần?
- ✅ Central identity store
- ✅ Track individual wallet balance
- ✅ Support authentication & 2FA

---

## 2. **groups** - Container cho mỗi expense-splitting scenario

### Ý nghĩa
- **Group Setup:** Tập hợp những người cùng chia sẻ chi tiêu
- **Currency & Timezone:** Mỗi group có base currency riêng

### Vai trò chính
```
VD: "Trip to Japan" Group
┌──────────────────────────────────────┐
│ Group: Trip to Japan                 │
│ baseCurrency: JPY                     │
│ timezone: Asia/Tokyo                 │
│ createdBy: user123                   │
│ Members: 4 people                    │
│                                      │
│ All invoices tạo trong group này     │
│ đều tính bằng JPY + convert to VND   │
└──────────────────────────────────────┘

Hoặc: "Apartment Rent" Group
┌──────────────────────────────────────┐
│ Group: Apartment Rent                │
│ baseCurrency: VND                     │
│ timezone: Asia/Ho_Chi_Minh           │
│ Members: 3 roommates                 │
│                                      │
│ Dùng cho recurring expenses (rent)   │
└──────────────────────────────────────┘
```

### Workflow
```
1. User A tạo group "Dinner with friends"
   → CREATE group { name, baseCurrency: 'VND', createdBy: userA }

2. Group được tạo → Ready để invite members

3. All expenses trong group dùng baseCurrency
   - Ticket: 40 USD → Convert to VND based on rate lock
   - Food: 500 JPY → Convert to VND based on rate lock

4. Settlement/queries dùng baseCurrency để standardize
```

### Tại sao cần?
- ✅ Logical grouping of expenses
- ✅ Standardize currency (prevents mixed calculations)
- ✅ Timezone matters for scheduling (subscriptions, billing dates)
- ✅ Soft delete: `deletedAt` field để preserve history

---

## 3. **group_members** - Define ai ở trong group + roles

### Ý nghĩa
- **Membership Table:** Track who belongs to which group
- **Role Management:** OWNER/ADMIN/USER có quyền khác nhau
- **Join/Leave History:** Khi join/leave + leftAt timestamp

### Vai trò chính
```
Bảng mapping:
┌────────────┬─────────┬─────────┬──────────────┐
│ groupId    │ userId  │ role    │ joinedAt     │
├────────────┼─────────┼─────────┼──────────────┤
│ trip1      │ user1   │ OWNER   │ 2024-03-01   │
│ trip1      │ user2   │ ADMIN   │ 2024-03-02   │
│ trip1      │ user3   │ USER    │ 2024-03-05   │
│ trip1      │ user4   │ USER    │ null (left)  │
└────────────┴─────────┴─────────┴──────────────┘

Roles:
- OWNER: Tạo group, full permissions
- ADMIN: Can issue payment requests, manage members
- USER: Can view, upload expenses, pay transfers
```

### Index Strategy
```
// Fast query: "Find all groups for user X"
→ index: userId
→ group_members.find({ userId: userX, leftAt: null })

// Fast query: "Is user X member of group Y?"
→ compound index: (groupId, userId)
→ group_members.findOne({ groupId: Y, userId: X })

// Find departed members
→ index: leftAt
→ group_members.find({ leftAt: { $ne: null } })
```

### Ví dụ business logic
```
1. User A invites user B via email
   → Create invite record + send email link

2. B clicks link + joins
   → Create group_members record with joinedAt

3. A (OWNER) wants to change B's role to ADMIN
   → Update group_members.role = ADMIN

4. B leaves group
   → Set leftAt = now (soft delete)
   → B's debts persist (still owes money)
   → B's balance history preserved
```

### Tại sao cần?
- ✅ Efficient member queries
- ✅ Role-based access control
- ✅ Track join/leave history (important for billing, settlements)

---

## 4. **invoices** - Record chi tiêu, who paid what

### Ý nghĩa
- **Expense Record:** Ghi nhận một khoản chi tiêu
- **Multi-currency Support:** Invoice có thể tính bằng currency khác group
- **Lock Status:** Khi in payment request, mark `isLocked`

### Vai trò chính
```
Ví dụ invoice:
┌────────────────────────────────────────┐
│ Invoice: Dinner at Restaurant X         │
│ groupId: trip1                          │
│ uploadedBy: user1                       │
│ amountTotal: 1,200 THB                  │
│ currency: THB                           │
│ baseCurrency (group): VND               │
│ exchangeRate: 1 THB = 1,000 VND        │
│ convertedAmountTotal: 1,200,000 VND    │
│ title: "Dinner - March 15"              │
│ imageUrl: "uploads/invoice123.jpg"      │
│ status: SUBMITTED (or LOCKED)           │
│ invoiceDate: 2024-03-15                │
└────────────────────────────────────────┘

Items breakdown:
→ invoice_items collection (separate)
   • Food: 800 THB
   • Drinks: 250 THB
   • Service: 150 THB
```

### Workflow
```
1. User A goes to restaurant, pays 1,200 THB
   → Upload receipt image + manual entry

2. System creates:
   a) Invoice record (master)
   b) InvoiceItems (line items: food, drinks, service)
   c) OriginalDebts (quien owes what)
      - User2 owes 400 THB to User1
      - User3 owes 400 THB to User1
      - etc...

3. Invoice remains in SUBMITTED state until...

4. Admin chooses "Issue Payment Request" for this invoice
   → isLocked: true
   → paymentRequestId: req123
   → status: LOCKED
   → Members must now pay transfers to settle

5. If invoice was wrong, update before payment request issued
   → After payment request, frozen (prevent data inconsistency)
```

### Multi-currency scenario
```
Trip to Japan:
┌─────────────────────────────────────┐
│ Invoice 1: Restaurant             │
│ amount: 5,000 JPY                   │
│ rate at creation: 1 JPY = 300 VND  │
│ convertedAmount: 1,500,000 VND      │
│ rateLockedAt: "2024-03-15"         │
│                                     │
│ After 1 week, rate changes:        │
│ 1 JPY = 310 VND                     │
│                                     │
│ BUT: Debt remains 1,500,000 VND    │
│ (rate is LOCKED)                    │
│                                     │
│ This prevents user claim:           │
│ "Why did my debt increase?"         │
└─────────────────────────────────────┘
```

### Tại sao cần?
- ✅ Centralize expense records
- ✅ Multi-currency support with rate locking
- ✅ isLocked prevents modification after payment request
- ✅ Audit trail: image URL + who uploaded + timestamp

---

## 5. **invoice_items** - Break down invoice into line items

### Ý nghĩa
- **Itemization:** Chi tiết từng dòng chi tiêu
- **Flexibility:** Mỗi item có quantity, unit price, description

### Vai trò chính
```
Invoice: Dinner = 1,200 THB
            ↓
Items:
┌─────────────────────────────────────┐
│ • Food (4x300 THB) = 1,200 THB      │
│ • Drinks (3x50 THB) = 150 THB       │
│ • Service (10%) = 135 THB           │
└─────────────────────────────────────┘

Purpose: Track WHAT was bought (not just total amount)
```

### Workflow
```
1. Upload invoice with items:
   items: [
     { description: "Pad Thai", quantity: 4, unitPrice: 300 },
     { description: "Beer", quantity: 3, unitPrice: 50 }
   ]

2. App calculates amount per item:
   amount = quantity × unitPrice

3. System can query:
   - "All invoices with item name 'Pad Thai'"
   - "Most expensive item across all invoices"
   - "Total food vs drinks split"

4. Alternative: Could embed items directly in invoices
   ❌ Problem: If 1 item changed, need rewrite entire invoice doc
   ✅ Solution: Separate collection = can update 1 item independently
```

### Tại sao cần?
- ✅ Detailed expense breakdown
- ✅ Independent update capability
- ✅ May support item-level split in future
- ✅ Audit trail: what exactly was purchased

---

## 6. **original_debts** - Core of debt settlement logic

### Ý nghĩa
- **Debt Registry:** Exactly who owes who how much
- **Per-Invoice Split:** Mỗi invoice → multiple debts (1 per person who benefits)
- **Exchange Rate Lock:** CRITICAL feature for multi-currency

### Vai trò chính
```
Invoice: Dinner 1,200 THB (User A paid)
             ↓
Split equally among 3 people:
         ↓         ↓         ↓
Original_Debt #1   #2        #3
┌──────────────┬──────────────┬──────────────┐
│ User2 owes   │ User3 owes   │ User4 owes   │
│ User A       │ User A       │ User A       │
│ 400 THB      │ 400 THB      │ 400 THB      │
│ = 120k VND   │ = 120k VND   │ = 120k VND   │
│ (locked)     │ (locked)     │ (locked)     │
└──────────────┴──────────────┴──────────────┘

Key fields:
- debtorId: User2 (người nợ)
- creditorId: User A (người được trả)
- originalAmount: 120,000 VND (fixed)
- remainingAmount: 120,000 VND (decreases as paid)
- exchangeRateUsed: 300 (1 THB = 300 VND)
- rateLockedAt: "2024-03-15" (NEVER changes)
```

### Why Exchange Rate Lock Matters
```
Scenario WITHOUT locking (WRONG):
Time 1: Create debt, 1 THB = 300 VND → debt = 1,200,000 VND
Time 2: Rate changes to 310 VND → debt auto-updates to 1,240,000 VND
        User claims: "This is fraud! I only owed 1,200,000!"

Scenario WITH locking (CORRECT):
Time 1: Create debt with rate 300 → debt = 1,200,000 VND
        exchangeRateUsed: 300
        rateLockedAt: "2024-03-15"
Time 2: Rate changes to 310 VND
        BUT: Debt still = 1,200,000 VND (immutable)
        exchangeRateUsed: 300 (never changes)
        Settlement is dispute-proof!
```

### Settlement Flow
```
Step 1: Invoice created → Original_debts created
        User2 owes User1: 100k (remainingAmount = 100k)

Step 2: User2 makes transfer payment to User1 (80k)
        System marks allocation: 80k pays this debt
        remainingAmount = 100k - 80k = 20k

Step 3: User2 makes another transfer (20k)
        remainingAmount = 20k - 20k = 0
        → Debt fully settled!

Query: "How much does User2 still owe User1?"
  sum(remainingAmount) where debtorId=User2, creditorId=User1
```

### Tại sao cần?
- ✅ Atomic debt records (no ambiguity)
- ✅ Rate locking prevents historical disputes
- ✅ remainingAmount tracks payment progress
- ✅ Enables settlement optimization algorithm

---

## 7. **payment_requests** - Bundle invoices for settlement push

### Ý nghĩa
- **Settlement Trigger:** Admin says "pay now or by X date"
- **Batch Operation:** Multiple invoices in 1 request
- **Deadline Enforcement:** expiresAt → reminder notifications

### Vai trò chính
```
Admin workflow:
┌────────────────────────────────────┐
│ "Issue Payment Request"             │
│ Select invoices: [Dinner, Taxi]    │
│ Expires in: 7 days                  │
│ issuedAt: 2024-03-15               │
│ expiresAt: 2024-03-22              │
│                                    │
│ → Sends notifications to all       │
│   members who owe money            │
│ "You have unpaid invoices!"        │
│ "Due by Mar 22"                    │
└────────────────────────────────────┘

Status machine:
ISSUED → (members pay) → PARTIALLY_PAID → PAID
      → (members ignore) → CANCELLED

DB fields:
- invoiceIds: [inv1, inv2, inv3]
- status: enum (ISSUED, PARTIALLY_PAID, PAID, CANCELLED)
- expiresAt: deadline
- lastReminderAt: track reminder frequency
- paidAt: when fully settled
- cancelledAt: if admin cancels
```

### Workflow
```
1. Admin creates payment request for 3 invoices
   → payment_requests: status=ISSUED

2. System locks all 3 invoices:
   → invoices[].isLocked = true
   → invoices[].paymentRequestId = req123

3. Members get notified:
   → "Haircut (500k) + Dinner (300k) + Taxi (100k)"
   → "Due by Mar 22"

4. User2 pays a transfer for 500k (haircut only)
   → status changes to PARTIALLY_PAID

5. User2 + User3 pay remaining 400k (dinner + taxi split)
   → status changes to PAID
   → expiresAt is passed, but settled anyway

6. If no one pays by expiresAt:
   → Can send reminder
   → Or admin cancels request
```

### Tại sao cần?
- ✅ Batch settlements for efficiency
- ✅ Deadline enforcement (payment pressure)
- ✅ Track which invoices are "active" (in request)
- ✅ Enable reminder workflow

---

## 8. **transfers** - Actual money movement record

### Ý nghĩa
- **Payment Proof:** "User A paid User B 500k on Mar 15"
- **Status Tracking:** PENDING → COMPLETED or FAILED
- **OTP Verification:** Secure payment confirmation
- **VNPay Integration:** Support gateway payment

### Vai trò chính
```
Transfer record:
┌──────────────────────────────────┐
│ Transfer #1                      │
│ fromUserId: user2 (payer)       │
│ toUserId: user1 (receiver)      │
│ amount: 500,000 VND              │
│ status: PENDING                  │
│ otp: "123456"                    │
│ otpExpiresAt: 2024-03-15T15:30  │
│ otpVerified: false               │
│ createdAt: 2024-03-15T15:00     │
│                                  │
│ Payment methods:                 │
│ Method 1: Balance (wallet)       │
│ Method 2: VNPay gateway          │
│   vnpayTxnRef: "20240315..."    │
│   vnpayTransDate: date           │
└──────────────────────────────────┘

Status flow:
PENDING → OTP sent → OTP verified → COMPLETED
       → Failure → FAILED
       → User cancels → CANCELLED
```

### Workflow with OTP
```
Step 1: User A initiates transfer
   → Create transfer: status=PENDING, send OTP to phone/email
   
Step 2: User A enters OTP
   → Verify OTP
   → otpVerified: true
   
Step 3: System processes payment
   a) If method=BALANCE:
      - Deduct from user2.balance
      - Add to user1.balance
      - Create 2 transaction records
      - status: COMPLETED
   
   b) If method=VNPAY:
      - Redirect to VNPay gateway
      - VNPay calls webhook
      - vnpayTxnRef stored
      - status: COMPLETED only after VNPay confirms

Step 4: Post-payment
   - Create transaction records (audit log)
   - Update original_debts.remainingAmount
   - Send confirmation notifications
```

### Allocation Mapping
```
One transfer may pay multiple debts:
Transfer: User2 pays 500k to User1

These 500k might cover:
- 200k for Dinner debt (allocation #1)
- 150k for Taxi debt (allocation #2)
- 150k for Drinks debt (allocation #3)

This mapping lives in transfer_debt_allocations
(not embedded in transfer for query efficiency)
```

### Tại sao cần?
- ✅ Immutable record of payment
- ✅ OTP security for sensitive transfers
- ✅ Support multiple payment methods (balance, VNPay)
- ✅ Link to payment gateway (vindication if disputes)
- ✅ Status machine prevents double-payment

---

## 9. **transfer_debt_allocations** - Map payments to debts

### Ý nghĩa
- **Payment Distribution:** Which debts does this transfer pay?
- **Many-to-Many Mapping:** 1 transfer → multiple debts

### Vai trò chính
```
Problem scenario:
Transfer: User2 → User1: 500k

Which debts does this pay?
- Dinner (300k)?
- Taxi (200k)?
- Drinks (200k)?

Solution: allocation table
┌────────────┬─────────────┬──────────────┐
│ transferId │ originalDbt │ allocAmount  │
├────────────┼─────────────┼──────────────┤
│ trans1     │ debt_din123 │ 300,000      │
│ trans1     │ debt_tax456 │ 150,000      │
│ trans1     │ debt_drk789 │ 50,000       │
└────────────┴─────────────┴──────────────┘

Usage:
1. Payment algorithm decides: "transfer 500k can pay debts efficiently"
2. Create 3 allocation records
3. For each debt, update remainingAmount:
   debt_din123: 300k → 0k (fully paid)
   debt_tax456: 200k → 50k (partially paid)
   debt_drk789: 150k → 100k (partially paid)

Query benefits:
→ "Which transfers paid debt X?"
  allocations.find({ originalDebtId: X })
→ "How much was allocated this transfer?"
  allocations.find({ transferId: Y }).sum(allocAmount)
```

### Why Separate Collection?
```
❌ If embed in transfers:
transfer {
  amount: 500k,
  allocations: [
    { debtId: 1, amount: 300k },
    { debtId: 2, amount: 150k },
    { debtId: 3, amount: 50k }
  ]
}

Query: "Find all payments for debt 123"
→ Must scan ALL transfers + check allocations array
→ NO INDEX on debtId (slow!)

✅ Separate table with indexes:
allocations { transferId, originalDebtId, allocAmount }
index: (originalDebtId) → fast lookup!
index: (transferId) → fast lookup!
```

### Tại sao cần?
- ✅ Flexible debt allocation
- ✅ Query efficiency with proper indexes
- ✅ Atomic allocation updates
- ✅ Support settlement optimization algorithm

---

## 10. **topups** - Wallet funding records

### Ý nghĩa
- **Deposit Channel:** How users add money to wallet
- **Payment Gateway:** Powered by VNPay
- **Status Tracking:** PENDING → COMPLETED or FAILED

### Vai trò chính
```
User topup workflow:
┌─────────────────────────┐
│ "Add funds to Wallet"   │
│ Amount: 500,000 VND     │
│ Click: "VNPay gateway"  │
│ → Redirect to VNPay    │
│ → User enters card     │
│ → VNPay charges card   │
│ → Callback webhook     │
│ → topup.status = ...   │
└─────────────────────────┘

topup record:
status: PENDING → After VNPay webhook → COMPLETED
                                      → FAILED

After successful topup (COMPLETED):
1. Update users.balance += amount
2. Create transaction record {
   type: TOP_UP,
   amount: +500,000,
   balanceBefore: X,
   balanceAfter: X + 500,000
}
```

### Index Strategy
```
// Fast: "Get all topups for user X"
index: (userId)
→ topups.find({ userId: userX })

// Fast: "Find topup by payment ref"
index: (vnpayTxnRef)
→ topups.findOne({ vnpayTxnRef: "vnpay_ref_123" })

// Fast: "Get pending topups"
index: (status)
→ topups.find({ status: "PENDING" })
```

### Tại sao cần?
- ✅ Track wallet funding source
- ✅ Link to payment gateway for reconciliation
- ✅ Status prevents duplicate processing
- ✅ Audit trail of money flow

---

## 11. **withdrawals** - Cash-out from wallet

### Ý nghĩa
- **Withdrawal Process:** User requests to withdraw balance to bank
- **OTP + Bank Details:** Secure withdrawal confirmation
- **Manual Processing:** Admin reviews and processes

### Vai trò chính
```
Withdrawal workflow:
┌─────────────────────────────────────┐
│ User: "Withdraw 300k to bank"      │
│ Bank: Vietcombank                   │
│ Account: 123456789                  │
│ Status: PENDING                     │
│                                     │
│ → Send OTP                          │
│ → User verifies OTP                 │
│ → Admin reviews (fraud check)       │
│ → Admin approves                    │
│ → Bank transfer sent                │
│ → Status: COMPLETED                 │
└─────────────────────────────────────┘

Status flow:
PENDING → OTP_SENT → OTP_VERIFIED → PROCESSING → COMPLETED
                                             → REJECTED
```

### Security
```
withdrawal {
  status: "PENDING",
  otp: "123456",
  otpExpiresAt: "2024-03-15T15:30",
  verifiedAt: null        // Set when OTP verified
}

Additional security:
1. Bank details storage (encrypted in real production)
2. Manual admin review before actual bank transfer
3. OTP expiry prevents brute force
4. processedAt timestamp for audit
```

### Tại sao cần?
- ✅ Withdraw wallet balance to real money
- ✅ OTP prevents unauthorized withdrawals
- ✅ Track withdrawal history
- ✅ Manual approval workflow for compliance

---

## 12. **subscriptions** - Recurring expense template

### Ý nghĩa
- **Recurring Config:** Define WHAT to bill, HOW OFTEN, HOW MUCH
- **Scheduler Trigger:** Auto-bill on nextBillingDate
- **Multiple Members:** Each with sharePercentage

### Vai trò chính
```
Example: Apartment Rent
┌──────────────────────────────────┐
│ subscription: apartment_rent     │
│ groupId: apartment_group         │
│ name: "Monthly Rent"             │
│ amount: 9,000,000 VND (total)   │
│ billingCycle: MONTHLY            │
│ nextBillingDate: 2024-04-01     │
│ status: ACTIVE                   │
│ createdBy: user_owner            │
│                                  │
│ Members:                         │
│ - User A: 40% = 3,600,000      │
│ - User B: 40% = 3,600,000      │
│ - User C: 20% = 1,800,000      │
└──────────────────────────────────┘

On 2024-04-01 (nextBillingDate):
Scheduler triggers:
1. Calculate share for each member
2. For each member:
   - Check balance
   - Deduct share or mark as failed
3. Record in billing_histories
4. Update nextBillingDate to 2024-05-01
5. Send notifications (success/failure)
```

### Multi-Member Split
```
Why subscription_members separate?

❌ If embed in subscription:
subscription {
  members: [
    { userId: A, sharePercentage: 40 },
    { userId: B, sharePercentage: 40 },
    { userId: C, sharePercentage: 20 }
  ]
}

Query: "Which subscriptions is user A member of?"
→ Scan all subscriptions, filter members array (slow!)

✅ Separate table:
subscription_members { subscriptionId, userId, sharePercentage }
index: (userId) → fast subscription lookup!
```

### Status & Retry
```
subscription {
  status: "ACTIVE" | "PAUSED" | "CANCELLED" | "EXPIRED" | "PAST_DUE"
  retryCount: 2         // Retry if billing fails
  failureReason: "..."  // Why last billing failed
  lastAttemptAt: date   // Avoid retry spam
}

Retry logic:
If billing fails → retryCount++, status=PAST_DUE
Scheduler retries on next date (if retryCount < max)
If all retries fail → status=FAILED, notify admin
```

### Tại sao cần?
- ✅ Automate recurring expenses
- ✅ Flexible member share split
- ✅ Retry logic for failed births
- ✅ Track historic billing

---

## 13. **billing_histories** - Audit log per billing cycle

### Ý nghĩa
- **Per-Cycle Record:** Every billing attempt is recorded
- **Member Results:** Detailed success/failure per member
- **Immutable Log:** For audit and debugging

### Vai trò chính
```
On subscription billing date:
System runs: Charge 9,000,000 (rent)

billing_histories record:
┌───────────────────────────────────┐
│ Billing: Apr 1, 2024              │
│ subscriptionId: sub_rent          │
│ amount: 9,000,000 VND             │
│ status: PARTIAL (2/3 succeeded)  │
│ totalCollected: 7,200,000         │
│                                   │
│ memberResults: [                  │
│   {                               │
│     userId: userA,                │
│     shareAmount: 3,600,000,       │
│     success: true                 │
│   },                              │
│   {                               │
│     userId: userB,                │
│     shareAmount: 3,600,000,       │
│     success: true                 │
│   },                              │
│   {                               │
│     userId: userC,                │
│     shareAmount: 1,800,000,       │
│     success: false,               │
│     reason: "Insufficient balance"│
│   }                               │
│ ]                                 │
└───────────────────────────────────┘
```

### Why Separate from Subscriptions?
```
❌ If just update subscription.lastBilledAt:
subscription {
  lastBilledAt: "2024-04-01",
  lastBillingResult: "PARTIAL_SUCCESS"  // vague
}
- No history of past attempts
- Can't store complex memberResults

✅ Separate billing_histories:
- Keep subscription lightweight
- Each cycle has detailed record
- Can query: "All billing records for subscription X"
- Can query: "Billing results for user Y"
- Full audit trail
```

### Queries
```
// Query: "Who failed to pay this billing cycle?"
billing_histories.findOne({ subscriptionId, billingDate })
  → memberResults.filter(r => !r.success)

// Query: "Success rate for subscription?"
billing_histories
  .find({ subscriptionId })
  .map(r => (r.status == 'SUCCESS') ? 1 : 0)
  → avg

// Query: "User X payment history?"
billing_histories.find({
  "memberResults.userId": userX
})
```

### Tại sao cần?
- ✅ Audit trail per cycle
- ✅ Member-level success/failure tracking
- ✅ Detailed failure reasons
- ✅ Historical analysis (success rates, patterns)

---

## 14. **subscription_members** - Who's part of subscription

### Ý nghĩa
- **Membership Mapping:** Which users bill in this subscription
- **Share Percentage:** How much each pays (flexible, not equal)

### Ý nghĩa
```
Rent subscription example:
3 roommates, but unequal pay:
- User A (largest room): 50%
- User B (medium room): 30%
- User C (smallest room): 20%

Total rent: 9,000,000
- User A: 4,500,000
- User B: 2,700,000
- User C: 1,800,000

subscription_members { subscriptionId, userId, sharePercentage }
This drives the billing split!
```

### Tại sao cần?
- ✅ Track subscription participation
- ✅ Flexible share allocation
- ✅ Easy lookup: "Billing members for subscription X"

---

## 15. **notifications** - Event-driven alerts

### Ý nghĩa
- **Event Log:** Track all system events
- **User Inbox:** Notifications for each user
- **Push + Email:** Delivery via multiple channels

### Vai trò chính
```
Event types trigger notifications:
1. EXPENSE_CREATED: "User A added receipt: Dinner (300k)"
2. PAYMENT_REQUEST_ISSUED: "Payment due by Mar 22"
3. PAYMENT_RECEIVED: "User A paid you 100k"
4. SETTLEMENT_CREATED: "Settlement proposal: 3 transfers"
5. SUBSCRIPTION_BILLING_FAILED: "Rent billing failed (insufficient balance)"
6. ROLE_CHANGED: "You were promoted to ADMIN"
etc...

Notification record:
┌────────────────────────────┐
│ userId: user2              │
│ type: PAYMENT_REQUEST_ISSUED
│ title: "Payment Request"   │
│ message: "Haircut + Dinner │
│           total 800k"      │
│ data: { requestId, amount}│
│ read: false                │
│ sentEmail: false           │
│ createdAt: 2024-03-15     │
└────────────────────────────┘

Delivery workflow:
1. Create notification
2. Send push notification (FCM) if user online
3. Send email if sentEmail=false
4. Mark sentEmail=true (prevent duplicate email)
5. User reads in app → mark read=true
```

### Index Optimization
```
// Query: "Get unread notifications for user"
Compound index: (userId: 1, read: 1, createdAt: -1)
→ Single index scan in order, no sort needed!

// Query: "Latest 20 notifications for user"
Compound index: (userId: 1, createdAt: -1)

// Query: "Mark all as read"
Index: (userId: 1)
```

### Tại sao cần?
- ✅ Keep users informed of events
- ✅ Multiple delivery channels (push + email)
- ✅ Read status tracking
- ✅ Event audit trail

---

## 16. **messages** - Real-time group chat

### Ý nghĩa
- **Chat History:** Permanent record of group discussions
- **Rich Content:** TEXT/IMAGE/FILE support
- **Threading:** Reply to specific messages

### Vai trò chính
```
Example chat in trip group:
User A: "When does plane land?"
User B: "5 PM at airport"
User C: [Uploads receipt image]
User B: "How much? I'll pay!"
User A: "Guys, let's split equally"

Message record:
┌──────────────────────────────────┐
│ groupId: trip1                   │
│ senderId: userA                   │
│ content: "When does plane land?"  │
│ messageType: TEXT                 │
│ createdAt: 2024-03-15T10:00      │
│ updatedAt: 2024-03-15T10:00      │
│                                  │
│ OR (with image):                 │
│ content: null                     │
│ messageType: IMAGE                │
│ fileUrl: "uploads/receipt.jpg"   │
│ fileName: "receipt.jpg"           │
│                                  │
│ OR (with reply):                 │
│ replyToId: msg123 (previous msg) │
│ Creates threading effect         │
└──────────────────────────────────┘
```

### Different from Notifications
```
NOTIFICATIONS: System → User (one-way alert)
- "Billing failed"
- "Payment received"
- User can't reply

MESSAGES: User → Group (discussion)
- "Hey guys, anyone free tomorrow?"
- Everyone in group sees
- Others can reply
- Real-time chat experience
```

### Tại sao cần?
- ✅ Group coordination
- ✅ Chat history for reference
- ✅ Real-time updates via WebSocket
- ✅ File sharing (receipts, etc.)

---

## 17. **invites** - Email-based membership invitation

### Ý nghĩa
- **Invite Flow:** Email link to join group
- **Token-Based:** Unique token per invite (prevent guessing)
- **Expiry:** PENDING → ACCEPTED or EXPIRED

### Vai trò chính
```
Admin (User A) invites User B:
1. Creates invite record:
   {
     groupId: trip1,
     emailInvite: "userb@gmail.com",
     token: "unique_token_xyz",
     status: PENDING,
     expiredAt: 2024-03-22 (7 days)
   }

2. Sends email:
   "Join our trip!"
   Link: https://app.com/invite/unique_token_xyz

3. User B clicks link:
   - Token validated
   - User B gets added to group_members
   - invite.status: ACCEPTED
   - User B now sees all group content

4. Or if not clicking in 7 days:
   - Scheduler marks: invite.status: EXPIRED
   - Link no longer works
```

### Why Token-Based?
```
❌ Direct join URL: "https://app.com/join/trip1/userb"
   - Easy to guess user IDs
   - Anyone can join if they know the URL pattern

✅ Token-based: "https://app.com/invite/xyz_random_token"
   - Token is random/unguessable
   - Token expires
   - Invite tied to specific email
   - Even more secure
```

### Tại sao cần?
- ✅ Email-based invite workflow
- ✅ Secure token prevents unauthorized joins
- ✅ Expiry prevents stale invites
- ✅ Soft join process (no auto-membership)

---

## 18. **locks** - Distributed lock mechanism

### Ý nghĩa
- **Concurrency Control:** Prevent race conditions
- **Resource Locking:** Only 1 process access resource at time
- **Timeout:** Expired locks automatically cleaned up

### Vai trò chính
```
Problem: Concurrent operations
Time 1: Admin issues payment request (locking invoices)
Time 2: Meanwhile, user tries to edit same invoice
→ Race condition / inconsistency

Solution: Distributed lock
1. Admin process:
   locks.create({
     resourceId: "invoice_123",
     lockType: "INVOICE_EDIT",
     expiresAt: now + 30s
   })
   → Proceed with invoice lock

2. User process:
   locks.findOne({ resourceId: "invoice_123"})
   → Found! Lock exists → Wait or reject
   
3. After admin finishes:
   locks.deleteOne({ resourceId: "invoice_123"})
   → Lock released, user can proceed
```

### When Needed
```
Critical sections:
1. Invoice → Payment Request (lock invoices)
2. Transfer payment processing (lock balance)
3. Subscription billing (lock member balances)
4. Settlement calculation (lock debts)
```

### Tại sao cần?
- ✅ Prevent double charges
- ✅ Prevent concurrent modifications
- ✅ Distribute across multiple servers
- ✅ Timeout prevents deadlock

---

## 19. **invites** - Email-based membership invitation

(See above - already covered)

---

## 🎯 System Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                  SPLITPAL SYSTEM                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│ ┌──────────────────────────────────────────────────┐  │
│ │ Identity & Wallet (users, transactions)          │  │
│ │ ↓ Authenticate + Track balance                   │  │
│ └──────────────────────────────────────────────────┘  │
│                     ↓                                   │
│ ┌──────────────────────────────────────────────────┐  │
│ │ Group Management (groups, group_members)         │  │
│ │ ↓ Create groups + Manage members & roles        │  │
│ └──────────────────────────────────────────────────┘  │
│                     ↓                                   │
│ ┌──────────────────────────────────────────────────┐  │
│ │ Expense Tracking (invoices, items, original_debts)
│ │ ↓ Upload expenses + Auto-create debts            │  │
│ │ ↓ Multi-currency with rate locking               │  │
│ └──────────────────────────────────────────────────┘  │
│                     ↓                                   │
│ ┌──────────────────────────────────────────────────┐  │
│ │ Settlement (payment_requests, transfers,         │  │
│ │ transfer_debt_allocations)                       │  │
│ │ ↓ Allocate payments to debts                     │  │
│ │ ↓ OTP + Payment gateway support                  │  │
│ └──────────────────────────────────────────────────┘  │
│                     ↓                                   │
│ ┌──────────────────────────────────────────────────┐  │
│ │ Wallet Management (topups, withdrawals)          │  │
│ │ ↓ Fund wallet + Withdraw to bank                │  │
│ │ ↓ Secure OTP verification                        │  │
│ └──────────────────────────────────────────────────┘  │
│                     ↓                                   │
│ ┌──────────────────────────────────────────────────┐  │
│ │ Recurring Billing (subscriptions, members,       │  │
│ │ billing_histories)                               │  │
│ │ ↓ Auto-bill on schedule                         │  │
│ │ ↓ Audit trail per cycle                         │  │
│ └──────────────────────────────────────────────────┘  │
│                     ↓                                   │
│ ┌──────────────────────────────────────────────────┐  │
│ │ Communication (notifications, messages)          │  │
│ │ ↓ System alerts + Group chat                     │  │
│ └──────────────────────────────────────────────────┘  │
│                     ↓                                   │
│ ┌──────────────────────────────────────────────────┐  │
│ │ Concurrency (locks)                              │  │
│ │ ↓ Distributed locks for critical sections       │  │
│ └──────────────────────────────────────────────────┘  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## 📊 Key Insights

| Collection | Purpose | Why It Exists | Critical For |
|-----------|---------|---------------|--------------|
| **users** | Core identity | User authentication + wallet | Everything |
| **groups** | Logical grouping | Organize expenses by context | Expense management |
| **group_members** | Membership tracking | Query efficiency + RBAC | Member management |
| **invoices** | Expense master | Central expense record | Debt calculation |
| **invoice_items** | Line item detail | Flexible itemization | Detailed records |
| **original_debts** | Debt registry | Who owes who + rate lock | Settlement |
| **payment_requests** | Settlement trigger | Batch payments + deadlines | Collections |
| **transfers** | Payment proof | Track actual money movement | Audit trail |
| **transfer_debt_allocations** | Debt→Payment mapping | Flexible allocation | Settlement algorithm |
| **topups** | Wallet funding | Money entry point | Wallet balance growth |
| **withdrawals** | Cash-out | Money exit point | User liquidity |
| **subscriptions** | Recurring template | Auto-billing config | Recurring expenses |
| **subscription_members** | Billing participants | Who gets billed + share % | Billing splits |
| **billing_histories** | Billing audit | Per-cycle record | Troubleshooting |
| **notifications** | Event alerts | User awareness | Engagement + UX |
| **messages** | Chat history | Group coordination | Communication |
| **invites** | Token-based join | Secure membership flow | User acquisition |
| **locks** | Concurrency control | Prevent race conditions | Data integrity |

---

Generated: March 24, 2026
