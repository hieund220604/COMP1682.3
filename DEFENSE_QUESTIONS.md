# Câu Hỏi Bảo Vệ Đồ Án — SplitPal

Tài liệu này tổng hợp **toàn bộ câu hỏi** mà hội đồng giảng viên có thể đặt ra, **tập trung đặc biệt vào các edge case** (tình huống biên) của từng tính năng.

> **Stack chính:** Flutter (Mobile) · Node.js/TypeScript/Express (Backend) · MongoDB · Redis · Socket.IO · Firebase FCM · VNPay · Gemini Vision API

---

## Mục Lục

1. [Kiến Trúc Tổng Quan](#1-kiến-trúc-tổng-quan)
2. [Xác Thực & Bảo Mật — Edge Cases](#2-xác-thực--bảo-mật--edge-cases)
3. [Quản Lý Nhóm — Edge Cases](#3-quản-lý-nhóm--edge-cases)
4. [Hóa Đơn & Chia Chi Phí — Edge Cases](#4-hóa-đơn--chia-chi-phí--edge-cases)
5. [Thuật Toán Settlement Engine — Edge Cases](#5-thuật-toán-settlement-engine--edge-cases)
6. [Payment Request & Transfer — Edge Cases](#6-payment-request--transfer--edge-cases)
7. [Ví Điện Tử & VNPay — Edge Cases](#7-ví-điện-tử--vnpay--edge-cases)
8. [Withdrawal — Edge Cases](#8-withdrawal--edge-cases)
9. [Subscription Billing — Edge Cases](#9-subscription-billing--edge-cases)
10. [Caching & Redis — Edge Cases](#10-caching--redis--edge-cases)
11. [Distributed Lock & Concurrency — Edge Cases](#11-distributed-lock--concurrency--edge-cases)
12. [OTP — Edge Cases](#12-otp--edge-cases)
13. [Database & Data Integrity — Edge Cases](#13-database--data-integrity--edge-cases)
14. [Real-time & Notification — Edge Cases](#14-real-time--notification--edge-cases)
15. [Multi-currency — Edge Cases](#15-multi-currency--edge-cases)
16. [Kiến Trúc Flutter — Edge Cases](#16-kiến-trúc-flutter--edge-cases)
17. [Câu Hỏi Nâng Cao & Lý Thuyết](#17-câu-hỏi-nâng-cao--lý-thuyết)

---

## 1. Kiến Trúc Tổng Quan

**Q1. Luồng dữ liệu đầy đủ từ người dùng tới database là gì?**

```
Flutter App
  → REST API (Express/TypeScript)
    → Redis (cache lookup)
    → MongoDB (primary store)
    → Redis (cache write / rate limit)
  ← Socket.IO event (real-time)
  ← Firebase FCM (push notification)
```

**Q2. Tại sao chọn MongoDB Atlas + Redis thay vì PostgreSQL + Redis?**

> MongoDB: schema-less tốt cho InvoiceItem có structure đa dạng (splits khác nhau từng item); horizontal scale dễ. Nhược: không có FK constraints → integrity enforcement ở application layer; JOIN kém hơn RDBMS; transaction ACID kém hiệu quả hơn PostgreSQL.

---

## 2. Xác Thực & Bảo Mật — Edge Cases

**Q3. Edge case: user đăng ký lần 2 với email đã tồn tại nhưng account còn `inactive`?**

> `SignUpUser()` kiểm tra `existingUser.status === 'inactive'` → cập nhật `passwordHash` + `displayName` (nếu cung cấp) → gửi lại OTP. Không tạo user mới, tránh accumulate user ghost trong DB.
>
> **Hỏi thêm:** Điều gì xảy ra nếu user `inactive` này đang ở giữa một lần verify OTP khác? → OTP cũ bị ghi đè bởi OTP mới. User phải dùng OTP mới nhất.

---

**Q4. Edge case: email OTP bị verify sai 3 lần — điều gì xảy ra?**

> `emailService.verifyOTP()` track `attempts` trong Redis record. Sau 3 lần sai → `deleteOtpRecord()` xóa sạch → user phải request OTP mới (`/auth/resend-otp`).
>
> **Hỏi thêm:** Nếu Redis down, attempts tracking lưu ở đâu? → `otpStore` in-memory Map trong process → không persistent qua restart, không share giữa multiple Node instances.

---

**Q5. Edge case: OTP transfer (5 phút) hết hạn trong khi user đang nhập?**

> `Transfer.otpExpiresAt < new Date()` → throw `'OTP has expired'`. User phải gọi lại `POST /transfers/{id}/initiate` để nhận OTP mới. Lưu ý: `initiatePayment()` không kiểm tra xem có OTP pending chưa hết hạn không → mỗi lần gọi sẽ overwrite OTP cũ.

---

**Q6. Edge case: user gọi `initiatePayment()` nhiều lần liên tiếp (spam request OTP)?**

> Hiện tại không có throttle riêng cho `/transfers/{id}/initiate`. Rate limiter chung (per IP) có thể bảo vệ phần nào, nhưng không phải per-user per-transfer. Đây là điểm cải tiến: thêm cooldown (ví dụ 60 giây) trước khi cho phép resend OTP transfer.

---

**Q7. Edge case: 2FA enabled nhưng `twoFactorSecret` bị null trong DB?**

> `speakeasy.totp.verify({ secret: null, ... })` → xem xét hành vi của thư viện speakeasy. Nếu secret null → verify luôn trả `false` → user bị lock out hoàn toàn. Cần validation khi enable 2FA đảm bảo `twoFactorSecret` luôn được set trước khi set `twoFactorEnabled = true`.

---

**Q8. Edge case: backup code 2FA được dùng — sau khi dùng thì sao?**

> `bcrypt.compare(code, hashedCode)` cho từng backup code. Khi tìm thấy match → `twoFactorBackupCodes.splice(index, 1)` → save → code đó không thể dùng lại. User chỉ có 8 codes; khi hết cần regenerate và setup 2FA lại.

---

**Q9. Edge case: JWT `default_secret` — vấn đề bảo mật?**

> Trong `authService.ts`:
> ```typescript
> jwt.sign(payload, process.env.JWT_SECRET || 'default_secret', options)
> jwt.verify(token, process.env.JWT_SECRET || 'hieu2206')
> ```
> `JWT_SECRET` fallback khác nhau giữa sign (`default_secret`) và verify (`hieu2206`) → **BUG**: token được sign với `default_secret` sẽ KHÔNG verify được với `hieu2206` nếu env không set. Đây là nghiêm trọng về bảo mật và correctness trong môi trường không có `JWT_SECRET`.

---

**Q10. Edge case: password reset token — có thể dùng nhiều lần không?**

> `resetPassword()` chỉ verify JWT (type='reset', 1h TTL) rồi update password. Không có blacklist → **token có thể dùng nhiều lần** cho đến khi hết 1 giờ. Cải tiến: lưu `passwordResetUsedAt` hoặc dùng `jti` trong JWT + Redis blacklist.

---

**Q11. Edge case: VNPay IPN gửi `vnp_TransactionStatus = '02'` (thất bại) nhưng có đúng `vnp_SecureHash`?**

> Server verify hash → hợp lệ. Kiểm tra `vnp_ResponseCode !== '00'` → không process top-up, không credit balance. TopUp status vẫn PENDING. VNPay có thể gửi lại IPN sau → idempotency check đảm bảo không double credit.

---

## 3. Quản Lý Nhóm — Edge Cases

**Q12. Edge case: OWNER cố gắng rời nhóm (leave group)?**

> `leaveGroup()` kiểm tra `membership.role === 'OWNER'` → throw `'Owner cannot leave the group. Transfer ownership first or delete the group.'`. OWNER buộc phải transfer ownership hoặc delete group trước.

---

**Q13. Edge case: user cố rời nhóm khi còn nợ chưa thanh toán?**

> `originalDebtService.canUserLeaveGroup()` kiểm tra `netBalance`. Nếu `netBalance < 0` (còn nợ người khác) → `canLeave: false`. Nếu `netBalance > 0` (người khác còn nợ mình) → cũng `canLeave: false`. **Hỏi thêm:** Tại sao cả 2 hướng đều chặn? → Nếu chỉ chặn người nợ, người có creditor balance rời đi → những người nợ mình không có cách thanh toán trong hệ thống.

---

**Q14. Edge case: user rời nhóm nhưng có subscription đang active?**

> `leaveGroup()` có comment `// BUG FIX`: query subscriptions theo `groupId` → `SubscriptionMember.updateMany({ userId, subscriptionId: { $in: subscriptionIds }, status: 'ACTIVE' }, { status: 'LEFT', leftAt: now })`. Đây là bug fix sau khi phát hiện user rời group vẫn bị charge subscription của group khác.

---

**Q15. Edge case: delete group khi còn thành viên hoặc payment request đang open?**

> `deleteGroup()` chỉ verify `membership.role === 'OWNER'`. Soft delete: set `Group.deletedAt = now`, tất cả Invoice có `groupDeleted: true`, tất cả Subscription có `groupDeleted: true`. **Không block** nếu còn payment request đang ISSUED/PARTIALLY_PAID → đây là potential data inconsistency.

---

**Q16. Edge case: invite token được accept bởi user đã là thành viên nhóm?**

> `acceptInvite()` kiểm tra `GroupMember.findOne({ groupId, userId, leftAt: null })` → throw `'You are already a member of this group.'`. Nếu user đã từng rời nhóm (`leftAt` không null) → không tìm thấy → tạo `GroupMember` mới → cho phép re-join.

---

**Q17. Edge case: ADMIN cố gắng set role = 'OWNER' cho thành viên khác?**

> `updateMemberRole()` kiểm tra:
> - `membership.role === 'ADMIN'` → không được set OWNER role (`'Cannot assign OWNER role. Use transfer ownership instead.'`)
> - ADMIN chỉ được update USER roles và không được grant ADMIN (`'Admin can only update USER roles'`, `'Admin cannot grant ADMIN role'`)

---

**Q18. Edge case: active invite tồn tại cho email, ADMIN tạo invite mới cho cùng email?**

> `createInvite()` check `Invite.findOne({ groupId, emailInvite, status: 'PENDING' })` → throw `'An active invite already exists for this email.'`. Phải đợi invite cũ expire hoặc bị revoke.

---

## 4. Hóa Đơn & Chia Chi Phí — Edge Cases

**Q19. Edge case: `splitType = EQUAL`, `assignedTo = []` (không ai được assign)?**

> `calculateShareForUser()`: `return item.assignedTo.length > 0 ? item.amount / item.assignedTo.length : 0`. Nếu `assignedTo` rỗng → share = 0 → không tạo OriginalDebt. Invoice vẫn được tạo nhưng không ai nợ ai.

---

**Q20. Edge case: debtor === uploader trong cùng một item (tự nợ chính mình)?**

> Trong `createInvoice()`:
> ```typescript
> if (debtorId === userId) continue; // Skip if debtor is the uploader
> ```
> Uploader không bao giờ nợ chính mình. **Hỏi thêm:** Nếu group có 3 người, item EQUAL gán cho cả 3, uploader là A → B và C nợ A phần của họ. A không nợ phần của mình (cost bearing).

---

**Q21. Edge case: `splitType = PERCENTAGE` nhưng tổng % = 99.99 (lỗi làm tròn)?**

> `Math.abs(total - 100) > 0.01` → nếu tổng = 99.99 thì `|99.99 - 100| = 0.01` → **không throw error** (threshold là strict `> 0.01`). Nếu tổng = 99.98 → `|99.98 - 100| = 0.02 > 0.01` → throw.

---

**Q22. Edge case: `splitType = WEIGHT` với một weight = 0?**

> `if (split.value <= 0) throw new Error('all share weights must be positive')`. Tuy nhiên validation chỉ ném lỗi cho weight ≤ 0. Nếu `totalWeight = 0` (mọi weight đều 0 bằng cách nào đó) → `share = item.amount * (split.value / 0)` = NaN. Cần defensive check `totalWeight || 1`.

---

**Q23. Edge case: CUSTOM split — user trong `splits` không có trong `assignedTo`?**

> `validateItemSplits()` kiểm tra "mọi user trong `assignedTo` phải có trong `splits`" (không thể thiếu). Nhưng không check "user trong `splits` có trong `assignedTo` không". Nếu có user extra trong `splits` → `calculateShareForUser()` sẽ tính cho họ nhưng họ không trong `assignedTo` → không bao giờ được `debtorId` → share bị ignore.

---

**Q24. Edge case: cập nhật invoice đã có OriginalDebt được allocate trong một Transfer (dù transfer PENDING)?**

> `updateInvoice()` chỉ kiểm tra `invoice.isLocked` (invoice LOCKED khi trong PaymentRequest). Nếu invoice SUBMITTED nhưng OriginalDebt của nó đã được allocate vào Transfer PENDING → `updateInvoice()` sẽ `OriginalDebt.deleteMany({ invoiceId })` → xóa OriginalDebt gốc. Transfer PENDING vẫn có `TransferDebtAllocation` trỏ về `originalDebtId` đã bị xóa → **data inconsistency** khi transfer được complete.

---

**Q25. Edge case: delete invoice khi đang có OriginalDebt với `remainingAmount < originalAmount` (đã trả một phần)?**

> `deleteInvoice()` chỉ kiểm tra `isLocked`. Nếu invoice SUBMITTED nhưng có OriginalDebt `remainingAmount` đã giảm (do Payment Request trước bị cancel và restore một phần) → xóa OriginalDebt đó → mất audit trail, người creditor có thể không nhận đủ tiền.

---

**Q26. Edge case: adjustment invoice trỏ về originalInvoiceId bị xóa?**

> `createAdjustmentInvoice()` set `originalInvoiceId` nhưng không có FK constraint. Nếu original invoice bị xóa sau đó → adjustment invoice còn `originalInvoiceId` trỏ về document đã xóa → query `Invoice.findById(originalInvoiceId)` trả `null` → phải handle ở UI layer.

---

## 5. Thuật Toán Settlement Engine — Edge Cases

**Q27. Edge case: `netBalances` map chứa user có balance = 0.009 (nhỏ hơn threshold 0.01)?**

> `greedySettle()`:
> ```typescript
> if (node.amount < -0.01) { debtors.push(...) }
> else if (node.amount > 0.01) { creditors.push(...) }
> ```
> User balance 0.009 bị ignore → không tạo transfer → hợp lý (tránh micro-transfers vô nghĩa).

---

**Q28. Edge case: chỉ có 1 debtor và 1 creditor, nhưng mutual debts?**

> Ví dụ: A nợ B 100k, B nợ A 60k:
> - `hasMutualDebts()` → true → dùng MinCostFlow
> - `pairNet[A][B] = 100k`, `pairNet[B][A] = 60k`
> - Netoff: `net = 100 - 60 = 40` → `pairNet[A][B] = 40`, `pairNet[B][A] = 0`
> - Kết quả: 1 transfer A→B 40k (thay vì 2 transfers nếu dùng Greedy)

---

**Q29. Edge case: `debtSettlementEngine.settle()` tạo transfer amount = 0.005 (nhỏ hơn 0.01)?**

> ```typescript
> if (transfer.amount <= 0.01) continue;
> ```
> Transfer micro này bị skip → không tạo Transfer document → không có `TransferDebtAllocation`. **Vấn đề**: OriginalDebt cho phần 0.005 VND đó không bao giờ được reduce → `remainingAmount > 0.01` threshold không đủ để lọc ra → OriginalDebt này sẽ tiếp tục bị đưa vào PaymentRequest lần sau.

---

**Q30. Edge case: `allocateDebtsForTransfer()` — tổng `remainingAmount` trong DB nhỏ hơn transfer amount do floating point?**

> Ví dụ: transfer 100.00 VND, nhưng OriginalDebt có `remainingAmount = [60.00, 39.99]` (tổng 99.99 do rounding):
> - `remaining = 100.00 - 60.00 - 39.99 = 0.01`
> - `remaining > 0.01` → false (strict) → **không throw error**
> Nếu `remaining = 0.011` → throw. Threshold `0.01` xử lý floating point errors.

---

**Q31. Edge case: settlement engine chạy khi nhóm có nhiều OriginalDebt từ nhiều PaymentRequest bị cancel?**

> `getNetBalances()` gọi `filterCancelledTransferDebts()` → lọc OriginalDebt mà ALL associated transfers đã CANCELLED. Nhưng logic phức tạp: nếu invoice status là SUBMITTED/LOCKED → giữ lại debt (valid cho request tiếp). Nếu tất cả cancelled và invoice không SUBMITTED → loại bỏ. **Edge case**: invoice bị LOCKED bởi request mới trong khi filter đang chạy → race condition.

---

**Q32. Edge case: MinCostFlow — sau netoff, `residualNodes` có balance nhỏ nhưng không khớp nhau?**

> Ví dụ sau netoff: node A có balance +0.001, node B có balance -0.001 → cả 2 `< 0.01` threshold → greedySettle() skip cả 2 → không có residual transfers → **0.002 VND chênh lệch** không bao giờ được settle. Đây là acceptable rounding behavior.

---

## 6. Payment Request & Transfer — Edge Cases

**Q33. Edge case: `createPaymentRequest()` khi `netBalances` map rỗng (tất cả debts đã settle)?**

> `debtSettlementEngine.settle()` → `greedySettle()` → debtors và creditors đều rỗng → `transfers = []` → `if (transfers.length === 0) throw new Error('No transfers needed')`. Request không được tạo.

---

**Q34. Edge case: lock released trước khi transaction commit trong `createPaymentRequest()`?**

> ```typescript
> try {
>     const result = await session.withTransaction(async () => { ... });
>     await invalidatePaymentRequestCache(groupId);
>     return this.getPaymentRequestById(...);
> } finally {
>     await session.endSession();
>     await lock.release(); // <-- released AFTER session ends
> }
> ```
> Lock release ở `finally` → đảm bảo release kể cả khi exception. Tuy nhiên, lock là 10 giây → nếu transaction mất > 10 giây → lock tự expire → another process có thể acquire lock trước khi transaction commit → **potential double payment request creation** nếu MongoDB transaction chưa commit.

---

**Q35. Edge case: `cancelSingleTransfer()` khi transfer là transfer duy nhất trong request?**

> User cancel transfer duy nhất → `hasCompletedTransfers = false` → cancel single transfer → `updateRequestStatus()` → `activeTransfers.filter(t => t.status !== 'CANCELLED')` → length = 0 → `newStatus = 'CANCELLED'` → unlock invoices → request tự động CANCELLED.

---

**Q36. Edge case: admin cancel PaymentRequest khi có transfer đang trong trạng thái OTP_PENDING (đã initiate nhưng chưa verify)?**

> `cancelPaymentRequest()` cancel tất cả PENDING transfers kể cả những cái đang chờ OTP. OTP được clear: `{ status: 'CANCELLED', otp: null, otpExpiresAt: null }`. Nếu user submit OTP sau khi transfer đã CANCELLED → `Transfer.findOneAndUpdate({ _id, status: 'PENDING', otp, otpExpiresAt: {$gt: now} })` → không tìm được (status đã CANCELLED) → throw `'Transfer already processed or OTP invalid'`.

---

**Q37. Edge case: `updateRequestStatus()` được gọi concurrently từ 2 transfers COMPLETED cùng lúc?**

> Không có lock cho `updateRequestStatus()`. 2 concurrent calls có thể cùng đọc `transfers`, cùng count, cùng set status. Do MongoDB document-level locking, cuối cùng một write sẽ win → status đúng. Nhưng `paidAt` có thể set sai thời điểm nếu 2 calls gần nhau. Thực tế không gây data corruption, chỉ có thể `paidAt` lệch vài milliseconds.

---

**Q38. Edge case: `verifyOTPAndPay()` — toUser không tìm thấy trong DB (đã bị xóa?)?**

> `User.findOneAndUpdate({ _id: transfer.toUserId }, ...)` → nếu không tìm thấy → `toUserDoc = null` → throw `'Recipient not found'` → transaction abort → balance không thay đổi. Trong MongoDB không có hard delete user nên thực tế hiếm xảy ra.

---

**Q39. Edge case: Transfer COMPLETED nhưng `createTransaction()` fail (network error, DB hiccup)?**

> Trong `verifyOTPAndPay()`, `createTransaction()` được gọi **sau** `session.endSession()` (ngoài transaction scope):
> ```typescript
> await session.withTransaction(async () => {
>     // ... transfer + balance update
> });
> // session ended
> await transactionService.createTransaction(...); // <-- ngoài transaction
> ```
> Nếu server crash tại đây: Transfer COMPLETED, balance updated, nhưng **không có Transaction audit record**. Đây là **known inconsistency** — điểm cải tiến quan trọng: đưa `createTransaction` vào trong session.

---

**Q40. Edge case: `cancelPaymentRequest()` refund — `toUser.balance` bị âm sau khi deduct?**

> ```typescript
> User.findOneAndUpdate({ _id: transfer.toUserId }, { $inc: { balance: -amount } }, ...)
> ```
> Không kiểm tra `balance >= amount` trước khi deduct trong refund. Nếu toUser đã chi tiêu số tiền nhận được, balance có thể âm sau refund. **Bug tiềm ẩn**: user có thể có negative balance. Cần thêm check hoặc accept negative balance là behavior hợp lệ trong refund.

---

## 7. Ví Điện Tử & VNPay — Edge Cases

**Q41. Edge case: VNPay gọi IPN 2 lần (retry) cho cùng 1 top-up thành công?**

> `accountService.completeTopUp()`:
> ```typescript
> if (topUp.status === TopUpStatus.COMPLETED) {
>     return; // Already completed — idempotent
> }
> ```
> Và bên trong transaction: `findOneAndUpdate({ _id: topUpId, status: 'PENDING' }, ...)` → lần 2 không tìm thấy (đã COMPLETED) → `updatedTopUp = null` → skip, không credit lần 2. **Idempotency được đảm bảo**.

---

**Q42. Edge case: VNPay IPN đến nhưng `vnp_TxnRef` không khớp với bất kỳ TopUp nào?**

> Controller trả `RspCode: '01', Message: 'Order not found'` cho VNPay. VNPay cần nhận `RspCode: '00'` để dừng retry. Nếu server luôn trả lỗi cho một TxnRef không tồn tại → VNPay sẽ retry nhiều lần → cần log và investigate.

---

**Q43. Edge case: user top-up qua VNPay nhưng `VNPAY_HASH_SECRET` sai trong config (misconfiguration)?**

> `buildSignData()` tạo hash với secret sai → VNPay gửi IPN với hash đúng → server verify lại với secret sai → hash không khớp → throw error / trả `RspCode: '97'` → **tất cả top-up fail silently**. Cần monitoring/alerting cho IPN verification failures.

---

**Q44. Edge case: `normalizeOrderInfo()` với tiếng Việt dài hơn 255 ký tự?**

> ```typescript
> .normalize('NFD')
> .replace(/[\u0300-\u036f]/g, '')  // remove diacritics
> .replace(/[^a-zA-Z0-9 ]/g, '')   // remove special chars
> .substring(0, 255)
> ```
> Truncate ở 255 ký tự — VNPay requirement. Không throw error, chỉ cắt bớt.

---

**Q45. Edge case: user có pending top-up (PENDING status) sau đó tạo thêm top-up mới?**

> `createTopUp()` không kiểm tra pending top-ups. User có thể có nhiều TopUp PENDING đồng thời. Nếu VNPay gọi IPN cho cả 2 → cả 2 được process → double credit. **Cần** giới hạn 1 pending top-up tại một thời điểm.

---

**Q46. Edge case: VNPay return URL được gọi trực tiếp bởi user (không phải redirect thật)?**

> Return URL thường là redirect sau khi user hoàn tất trên VNPay. Nếu user bookmark và gọi lại → server verify hash → nếu hash valid (params không đổi) → sẽ process lại. Đây là lý do **không nên** update balance trong return URL handler, chỉ trong IPN handler (được gọi từ server VNPay, không thể forge).

---

## 8. Withdrawal — Edge Cases

**Q47. Edge case: user initiate withdrawal, rồi trong 10 phút balance giảm (do subscription charge)?**

> `initiateWithdrawal()` check balance tại thời điểm tạo withdrawal. `verifyOTP()` dùng:
> ```typescript
> User.findOneAndUpdate({ _id: userId, balance: { $gte: amount } }, { $inc: { balance: -amount } }, ...)
> ```
> Nếu balance đã giảm → `findOneAndUpdate` không tìm thấy (balance không đủ) → throw `'Insufficient balance'` → transaction abort → withdrawal CANCELLED (do `lockedWithdrawal` đã set COMPLETED trong cùng findOneAndUpdate → cần xem lại logic).

---

**Q48. Edge case: 2 withdrawal requests cùng lúc cho cùng 1 user?**

> Không có lock per-user cho withdrawal. 2 requests song song:
> - Cả 2 tạo Withdrawal document PENDING
> - Cả 2 check balance → đủ
> - Cả 2 gửi OTP (2 emails khác nhau)
> - Nếu user verify cả 2 OTP → `findOneAndUpdate({ balance: { $gte: amount } })` → lần 2 có thể fail nếu balance không đủ sau lần 1. **Thiếu** limit 1 pending withdrawal per user.

---

**Q49. Edge case: `DEFAULT_WITHDRAWAL_BANK` hardcode trong code — security/flexibility problem?**

> ```typescript
> const DEFAULT_WITHDRAWAL_BANK = {
>     bankName: 'NCB',
>     accountNumber: '9704198526191432198',
>     accountName: 'NGUYEN VAN A'
> };
> ```
> Bank info hardcode cho **tất cả users** → đây là system withdrawal account. Thực tế production cần: user nhập bank account của mình → verify account → lưu an toàn.

---

## 9. Subscription Billing — Edge Cases

**Q50. Edge case: subscription `billingCycle = MONTHLY`, ngày 31/1 → `nextBillingDate` tính thế nào?**

> ```typescript
> next.setMonth(next.getMonth() + 1);
> ```
> `new Date('2024-01-31').setMonth(1)` → JavaScript tự overflow tháng 2 (28/29 ngày) → **2024-03-02** (3 tháng 2). Đây là JavaScript behavior, không phải lỗi ngay, nhưng user kỳ vọng billing vào cuối tháng 2 (28/29 tháng 2). Fix: dùng `date-fns/addMonths` để handle edge case này chuẩn hơn.

---

**Q51. Edge case: subscription bị charged khi group đã bị soft delete?**

> `processRenewals()` query `Subscription.find({ status: ACTIVE, nextBillingDate: { $lte: now } })`. Subscription của group soft-deleted sẽ có `groupDeleted = true` nhưng query không filter field này. Subscription vẫn có thể bị charge sau khi group deleted → **bug tiềm ẩn**.

---

**Q52. Edge case: `processSingleSubscription()` chạy khi tất cả thành viên đã rời nhóm?**

> `SubscriptionMember.find({ subscriptionId, status: 'ACTIVE' })` → empty → `members = []`. Subscription billing logic: `members.filter(m => m.userId !== creatorId)` → không ai bị charge. `totalCollected = 0` → BillingHistory với `totalCollected = 0` → subscription `nextBillingDate` vẫn được update → subscription tiếp tục "active" vô tận mà không charge ai.

---

**Q53. Edge case: optimistic lock trong subscription billing — `PROCESSING` status bị stuck?**

> ```typescript
> await Subscription.findOneAndUpdate(
>     { _id: sub._id, status: sub.status },
>     { $set: { status: 'PROCESSING' as any } }
> );
> ```
> Nếu server crash trong khi billing → subscription vẫn ở status `'PROCESSING'`. Scheduler lần sau sẽ query `status: { $in: [ACTIVE, PAST_DUE] }` → **không tìm thấy** PROCESSING subscription → subscription bị stuck vĩnh viễn. Cần timeout: nếu `processingStartedAt` > N phút → reset về ACTIVE.

---

**Q54. Edge case: subscription billing charge một số members thành công, một số fail (PARTIAL)?**

> `processSingleSubscription()`: charge từng member theo loop. Nếu member A success, member B fail:
> - B không bị charge (nhưng đã committed A's charge trong session)
> - `failedMembers.length > 0` → status `PAST_DUE` hoặc CANCELLED
> - BillingHistory `status: 'FAILED'` với `membersCharged: 0` (vì code chỉ set `membersCharged: 0` cho FAILED case)
>
> **Vấn đề**: Member A đã bị charge nhưng BillingHistory ghi `membersCharged: 0`. Nếu sau đó retry, A bị charge lần 2 → double charge.

---

**Q55. Edge case: subscription amount thay đổi — share của các members được recalculate thế nào?**

> `updateSubscription()` nếu `updates.amount` thay đổi:
> ```typescript
> const members = await SubscriptionMember.find({ subscriptionId, status: 'ACTIVE', userId: { $ne: creatorBy } });
> ```
> Chỉ recalculate cho non-creator members. Creator KHÔNG bị charge (business rule). `base = floor(amount / memberCount)`, `remainder = amount - base * memberCount` → member đầu tiên nhận `base + remainder` → fair distribution với int arithmetic.

---

**Q56. Edge case: subscription `retryCount = 3` nhưng billing thành công ở lần retry thứ 3?**

> `if (sub.status === SubscriptionStatus.PAST_DUE && sub.retryCount >= 3)` → `status = CANCELLED`, **không thử billing**. Nếu member vừa top-up đúng lúc → subscription bị cancel không cần thiết. Cải tiến: thử billing trước khi cancel (thứ tự: charge → if fail → increment retryCount → if >= 3 → cancel).

---

## 10. Caching & Redis — Edge Cases

**Q57. Edge case: Redis `SCAN` trong `deleteKeysByPrefix()` có thể bị race condition?**

> `SCAN` với cursor: nếu trong lúc đang scan, có write mới tạo key với prefix đó → key mới có thể không bị xóa (SCAN cursor đã đi qua vị trí của key đó). **Acceptable**: cache sẽ expire tự nhiên theo TTL.

---

**Q58. Edge case: Redis down trong khi `setJsonCache()` đang thực thi?**

> `getRedis()` trả `null` nếu `!redisConnected` → `setJsonCache()` early return, không cache. App vẫn hoạt động nhưng mọi request đều miss cache → tăng tải MongoDB đáng kể.

---

**Q59. Edge case: cache hit nhưng dữ liệu đã stale (TTL chưa hết nhưng DB đã update)?**

> Trường hợp: user A update invoice → `invalidateInvoiceCache(groupId)` → xóa cache group đó. Nhưng nếu user B đang query invoice của group khác cùng prefix → không bị ảnh hưởng. **Cross-group**: fine. **Same-group stale**: `deleteKeysByPrefix` cover tất cả key của group → minimal staleness.

---

**Q60. Edge case: `deleteKeysByPrefix()` xóa key của nhiều groups trong cùng prefix?**

> `buildRedisKey('cache', 'invoice', groupId)` → prefix là `splitpal:cache:invoice:{groupId}`. SCAN với `splitpal:cache:invoice:{groupId}*` chỉ match keys của groupId cụ thể. Không xóa nhầm group khác.

---

**Q61. Edge case: OTP lưu trong in-memory `otpStore` khi Redis down — restart server thì sao?**

> `otpStore` là `Map` in-memory → **mất khi server restart**. User đang chờ OTP phải request lại. Nếu nhiều Node instances → mỗi instance có `otpStore` riêng → user gửi OTP đến instance khác → không tìm thấy record → verify fail. **Scale problem**.

---

## 11. Distributed Lock & Concurrency — Edge Cases

**Q62. Edge case: Redis lock expire trước khi business logic hoàn thành?**

> `acquireLock('payment_request', groupId, 10_000)` → 10 giây TTL. Nếu `createPaymentRequest()` mất > 10 giây (MongoDB slow, nhiều invoices) → lock auto-expire trong Redis. Process 2 acquire lock → cả 2 cùng tạo PaymentRequest. MongoDB transaction check `existingRequest` → thứ 2 sẽ fail với `'There is already an open payment request'`. **Double protection**: Redis lock (performance) + DB check (correctness).

---

**Q63. Edge case: Redis lock acquired nhưng MongoDB lock (fallback) không available?**

> `acquireLock()`: thử Redis trước. Nếu Redis có → trả Redis lock. Nếu Redis không available → thử Mongo lock. Nếu cả 2 fail → trả `null` → throw `'Another payment request is being created.'`. App được thiết kế fail-safe: từ chối tạo mới thay vì risk double creation.

---

**Q64. Edge case: MongoDB lock TTL index — độ trễ cleanup là bao lâu?**

> MongoDB TTL index background job chạy mỗi **60 giây** → expired locks có thể tồn tại tối đa ~60 giây sau khi expire. Trong 60 giây đó, `findOneAndUpdate` với filter `expiresAt <= now` sẽ tìm được document expired → acquire lock thành công (vì filter đúng). **Không phải vấn đề** vì filter là real-time check, không phụ thuộc vào cleanup.

---

**Q65. Edge case: 2 subscription billing jobs chạy song song (2 server instances)?**

> Optimistic lock:
> ```typescript
> const locked = await Subscription.findOneAndUpdate(
>     { _id: sub._id, status: sub.status },  // chỉ update nếu status chưa thay đổi
>     { $set: { status: 'PROCESSING' } }
> );
> if (!locked) continue; // Skip nếu đã bị grab bởi instance khác
> ```
> Instance đầu: `status: ACTIVE → PROCESSING`. Instance 2: query tìm `ACTIVE` → không tìm thấy (đã PROCESSING) → skip. **Đây là giải pháp** cho double-charge trong horizontal scale.

---

## 12. OTP — Edge Cases

**Q66. Edge case: OTP brute force — rate limiter có đủ không?**

> Transfer OTP: `verifyOTPAndPay()` không có per-transfer OTP attempt counter. Rate limiter chung (IP-based) có thể block sau N requests. Nhưng attacker từ nhiều IPs có thể bypass. **Fix**: thêm attempt counter vào Transfer document, lock sau 3 lần sai.

---

**Q67. Edge case: OTP email deliverability — email service không available?**

> `initiatePayment()`:
> ```typescript
> try {
>     await emailService.sendOTPEmail(user.email, otp);
> } catch (error) {
>     console.error('Failed to send OTP email:', error);
>     // Continue anyway - user can request resend
> }
> ```
> OTP vẫn được save vào Transfer document dù email fail. User không nhận được OTP nhưng hệ thống không báo lỗi ra client. **UX bug**: user cần cơ chế biết email failed để request resend ngay.

---

**Q68. Edge case: withdrawal OTP (10 phút) vs transfer OTP (5 phút) — tại sao khác nhau?**

> Transfer OTP 5 phút: giao dịch thông thường, cần nhanh để tránh session timeout.
> Withdrawal OTP 10 phút: rút tiền về bank account thực tế, cần thêm thời gian user verify thông tin bank, ký xác nhận trên app.

---

**Q69. Edge case: user có 2 withdrawals pending cùng lúc, submit cùng 1 OTP cho cả 2?**

> Mỗi Withdrawal có OTP riêng (generated independently). Cùng 1 email nhưng OTP khác nhau (random 6 số). User nhận 2 emails → submit OTP đúng cho đúng withdrawal ID. **Không có cross-contamination** vì verify theo `withdrawalId`.

---

## 13. Database & Data Integrity — Edge Cases

**Q70. Edge case: `OriginalDebt.remainingAmount` bị âm do floating point?**

> `reduceDebt()`:
> ```typescript
> const newRemaining = Math.max(0, debt.remainingAmount - amount);
> await OriginalDebt.findByIdAndUpdate(id, { remainingAmount: Math.round(newRemaining * 100) / 100 });
> ```
> `Math.max(0, ...)` đảm bảo không bao giờ âm. `Math.round(...*100)/100` đảm bảo 2 decimal places.

---

**Q71. Edge case: 2 calls đến `reduceDebt()` cùng lúc cho cùng 1 `originalDebtId`?**

> `reduceDebt()` dùng `findByIdAndUpdate` (non-atomic đối với concurrent reads):
> - Call 1: đọc `remainingAmount = 100`, tính `newRemaining = 40`
> - Call 2: đọc `remainingAmount = 100` (chưa update), tính `newRemaining = 40`  
> - Cả 2 cùng set `remainingAmount = 40` → total reduced 60, nhưng 2 transfers đều có `allocatedAmount = 60` → **double spending**
>
> Fix: dùng `{ $inc: { remainingAmount: -amount } }` thay vì read-compute-write, hoặc đảm bảo chỉ gọi `reduceDebt` trong session transaction.

---

**Q72. Edge case: `filterCancelledTransferDebts()` race condition — invoice status thay đổi giữa chừng?**

> ```typescript
> const invoices = await Invoice.find({ _id: { $in: invoiceIds } });
> // ... sau đó check invoice.status
> ```
> Nếu giữa query và check, invoice bị lock bởi request mới → filter sẽ loại bỏ debt đó (invoice không còn SUBMITTED) → **debt bị bỏ qua** trong settlement → có thể tạo incorrect transfers.

---

**Q73. Edge case: `updateRequestStatus()` được gọi khi request đã PAID (sau khi unlock invoices)?**

> ```typescript
> if (newStatus === 'CANCELLED' || newStatus === 'PAID') {
>     await Invoice.updateMany({ _id: { $in: request.invoiceIds } }, { isLocked: false, status: 'SUBMITTED' });
> }
> ```
> Nếu `updateRequestStatus()` gọi sau khi request đã PAID (do concurrent transfer completion) → invoices bị unlock lại → **có thể bị include vào PaymentRequest tiếp theo** dù đã paid. Cần kiểm tra `request.status !== 'PAID'` trước khi unlock.

---

**Q74. Edge case: compound index `{ name: 1, groupId: 1 }` trên Lock với `unique: true` — upsert fail race?**

> 2 concurrent `findOneAndUpdate(..., { upsert: true })` cho cùng `name + groupId`:
> - Cả 2 query → không tìm thấy (hoặc tìm thấy đã expired)
> - Cả 2 cố upsert → 1 success, 1 nhận `DuplicateKeyError` (code 11000)
> - Error handler: `if (error.code === 11000) return null` → fail gracefully → lock not acquired
> **Correct behavior**.

---

## 14. Real-time & Notification — Edge Cases

**Q75. Edge case: Socket.IO auth token hết hạn trong session dài (7 ngày)?**

> Middleware Socket.IO verify token tại thời điểm **connect**. Sau khi connected, token không được re-verify. Nếu server restart → client phải reconnect → re-verify. Trong session liên tục 7 ngày không disconnect: server có thể push events đến socket nhưng không biết token đã expired. Cần periodic re-auth hoặc shorter JWT TTL.

---

**Q76. Edge case: FCM token invalid (device uninstalled app) — gửi push notification fail?**

> `admin.messaging().send({ token: user.fcmToken, ... })` → Firebase trả `messaging/registration-token-not-registered`. Hiện tại không có error handling rõ ràng → error bị swallow hoặc log → `fcmToken` không được clear → mỗi lần gửi notification đến user đó đều fail. **Cải tiến**: catch `registration-token-not-registered` → set `User.fcmToken = null`.

---

**Q77. Edge case: `createBulkNotifications()` với mảng userIds rỗng?**

> Nếu `chargedUserIds.length === 0` → skip gọi `createBulkNotifications()`. Subscription creator không bị charge → không cần notify creator. Logic đúng.

---

**Q78. Edge case: notification gửi fail — có retry không?**

> `notificationService.createNotification()` là best-effort. Được wrap trong try/catch ở nhiều nơi:
> ```typescript
> try {
>     await notificationService.createBulkNotifications(...);
> } catch (_) { /* Notification failure should not block billing result */ }
> ```
> Không có retry queue. Notification mất → user không biết. **Acceptable**: notification là non-critical path.

---

## 15. Multi-currency — Edge Cases

**Q79. Edge case: `exchangeRateService.getRate('VND', 'VND')` (same currency)?**

> `getRate()` nên return 1.0 cho same currency. Nếu không có guard và API returns error hoặc null → `exchangeRate = null` → `convertedAmountTotal = null` → Invoice không có converted amount → downstream calculations break. Cần `if (fromCurrency === toCurrency) return 1`.

---

**Q80. Edge case: 2 foreign currency invoices trong cùng PaymentRequest với tỷ giá khác nhau?**

> ```typescript
> const allSameForeignCurrency = foreignInvoices.every(inv => inv.currency === firstForeign.currency);
> if (allSameForeignCurrency) {
>     exchangeRateInfo = { originalCurrency: firstForeign.currency, exchangeRate: firstForeign.exchangeRate! };
> }
> // else: exchangeRateInfo = null (mixed currencies not supported for Transfer display)
> ```
> Mixed currencies: Transfer được tạo với `convertedCurrency = baseCurrency` (VND) nhưng không có `originalCurrency` info. **OriginalDebt đã lock tỷ giá** → debt amount đúng, nhưng Transfer không hiển thị conversion info cho user.

---

**Q81. Edge case: `exchangerate-api.com` trả về JSON không có currency cần (ví dụ: KPW — Won Bắc Triều Tiên)?**

> ```typescript
> const STATIC_RATES_TO_VND = { VND: 1, USD: 25400, EUR: 27600, ... };
> ```
> `getRate()`: nếu API không có KPW và STATIC_RATES không có KPW → throw error hoặc return `undefined`. Invoice creation fail. User nhận lỗi "Cannot get exchange rate for KPW".

---

**Q82. Edge case: tỷ giá locked tại thời điểm tạo invoice = 25,000 VND/USD, nhưng 1 tháng sau thực tế 28,000?**

> OriginalDebt lưu `exchangeRateUsed = 25000`. Transfer sẽ tính theo 25000 (không phải 28000). Người nhận (creditor) nhận đúng theo tỷ giá lúc chi tiêu, không bị thiệt do biến động tỷ giá. **Design decision**: fairness được ưu tiên hơn real-time accuracy.

---

## 16. Kiến Trúc Flutter — Edge Cases

**Q83. Edge case: `getIt<GroupRepository>()` được gọi trước khi DI container được khởi tạo?**

> `GetIt.instance.registerLazySingleton(...)` trong `di/injection_container.dart` phải được gọi trong `main()` trước `runApp()`. Nếu thứ tự sai → `GetIt` throw `StateError: Expected a Factory/Singleton registration of type GroupRepository`. App crash tại launch.

---

**Q84. Edge case: `Either<Failure, T>` — nếu fold() bị gọi sai side?**

> ```dart
> result.fold(
>     (failure) => // handle error
>     (data) => // handle success
> );
> ```
> Nếu developer call `result.right` trực tiếp khi result là `Left(Failure)` → `dartz` throw `NoSuchMethodError`. Pattern `fold()` buộc handle cả 2 cases → safer.

---

**Q85. Edge case: Dio HTTP client timeout — default timeout là bao lâu? Retry?**

> Phụ thuộc config trong `core/network/`. Nếu không set `connectTimeout`/`receiveTimeout` → mặc định vô hạn → user chờ mãi mãi nếu server không respond. Best practice: 30s connect, 60s receive; retry 1-2 lần cho idempotent requests (GET).

---

## 17. Câu Hỏi Nâng Cao & Lý Thuyết

**Q86. Giải thích cơ chế HMAC-SHA512 dùng trong VNPay. Tại sao không dùng MD5 hoặc SHA256?**

> HMAC = `Hash(key XOR opad || Hash(key XOR ipad || message))`. Key là `VNPAY_HASH_SECRET`. SHA512 → 512-bit output → collision resistance cao hơn SHA256. VNPay quy định SHA512. MD5/SHA256 có thể có collision attacks tiềm năng; SHA512 an toàn hơn cho financial data.

---

**Q87. Phân tích độ phức tạp thuật toán của Greedy Settlement với N người?**

> - Build debtors/creditors: O(N)
> - Sort descending: O(N log N)  
> - Two-pointer matching: O(N)
> - Total: **O(N log N)**
>
> Với N thành viên nhóm thực tế (< 50) → negligible. Số transfers tối đa = N-1 (optimal cho bài toán này khi không có mutual debts).

---

**Q88. Tại sao MinCostFlow trong SplitPal không phải "minimum cost flow" thật sự (đúng tên)?**

> "MinCostFlow" ở đây là tên gọi thân thiện cho **debt netoff** (cancellation of mutual debts). Minimum Cost Flow thật sự là bài toán trên graph với edges có capacity và cost, tối thiểu hóa tổng cost × flow. Trong SplitPal, chỉ có bước netoff bilateral debts + Greedy fallback → thực ra là **"Bilateral Netting + Greedy"**, không phải MCF đầy đủ. Tuy nhiên cho scale nhỏ (<50 users), kết quả xấp xỉ optimal.

---

**Q89. TOTP `window: 2` nghĩa là gì chính xác? Mỗi time step là bao nhiêu giây?**

> TOTP time step = 30 giây. `window: 2` = chấp nhận codes từ `t - 2*30s` đến `t + 2*30s` = **±60 giây** drift. Tổng window = 150 giây (5 codes: t-2, t-1, t, t+1, t+2). Đủ để compensate clock drift giữa server và mobile device.

---

**Q90. `Math.round(amount * 100) / 100` — tại sao không dùng `toFixed(2)`?**

> `toFixed(2)` trả `string`, phải parse lại (`parseFloat(x.toFixed(2))`). `Math.round(x * 100) / 100` trả `number` trực tiếp → dùng trong arithmetic ngay. Tuy nhiên cả 2 có thể có floating point edge case: `Math.round(1.005 * 100) / 100 = 1` (thay vì 1.01 do binary float). **Thực tế**: với VND (integer currency), không có decimal → không ảnh hưởng.

---

**Q91. Khi nào nên dùng `session.withTransaction()` vs `session.startTransaction()` manual?**

> `withTransaction()` auto-retry on transient errors (network hiccup, write conflict) với **exponential backoff** (MongoDB driver v4+); auto-commit/abort. Manual `startTransaction()` phải tự retry. SplitPal dùng cả 2 (subscription billing dùng manual). **Best practice**: luôn dùng `withTransaction()` trừ khi cần control retry logic.

---

**Q92. Giải thích "optimistic locking" trong subscription billing. Tại sao gọi là "optimistic"?**

> "Optimistic" = giả sử không có concurrent access → không lock trước khi đọc → chỉ verify khi write:
> ```typescript
> findOneAndUpdate({ _id: sub._id, status: sub.status }, ...)
> ```
> Nếu status đã thay đổi (instance khác đang process) → update fail (trả null) → skip. Khác với "pessimistic locking" (lock record trước khi đọc, blocking).

---

**Q93. Tại sao `reduceDebt()` dùng read-compute-write thay vì `$inc`? Rủi ro?**

> ```typescript
> const debt = await OriginalDebt.findById(id);     // READ
> const newRemaining = Math.max(0, debt.remainingAmount - amount); // COMPUTE
> await OriginalDebt.findByIdAndUpdate(id, { remainingAmount: newRemaining }); // WRITE
> ```
> Rủi ro: **lost update** nếu concurrent calls. Fix đúng đắn: `{ $inc: { remainingAmount: -amount } }` kết hợp với `{ $max: [0, "$remainingAmount"] }` (MongoDB 4.2+ với aggregation pipeline update). Hoặc đảm bảo `reduceDebt` luôn được gọi trong transaction.

---

**Q94. Giải thích tại sao Invoice unlock (status → SUBMITTED) xảy ra trong cả `cancelPaymentRequest()` VÀ `updateRequestStatus()`?**

> Có 2 code paths dẫn đến invoice unlock:
> 1. **Explicit cancel** (`cancelPaymentRequest()`): admin/payer cancel → unlock trong transaction
> 2. **Auto-detect** (`updateRequestStatus()`): tất cả active transfers cancelled → newStatus = CANCELLED → unlock
>
> **Potential double-unlock**: cả 2 gọi `Invoice.updateMany({ isLocked: false })` → idempotent (set same value) → không gây corruption nhưng thừa. Có thể có race condition giữa 2 code paths.

---

**Q95. Nếu phải thiết kế lại hệ thống với scale 1 triệu user, thay đổi gì quan trọng nhất?**

> Thứ tự ưu tiên:
> 1. **Message queue** (BullMQ/Kafka): tách billing, notification, email ra worker riêng → tránh blocking API thread
> 2. **Event sourcing** cho Transaction: mọi balance change là event → reliable audit trail
> 3. **Sharding MongoDB** theo `groupId` → distribute load
> 4. **S3/CDN** cho file uploads (ảnh hóa đơn)
> 5. **Separate auth service** với refresh token + Redis token blacklist
> 6. **gRPC** cho internal service-to-service (billing ↔ notification)

---

*Tài liệu được tổng hợp dựa trên source code thực tế của SplitPal — đặc biệt tập trung vào edge cases, bugs tiềm ẩn, và design decisions cần bảo vệ trước hội đồng.*

*Chúc bảo vệ thành công! 🎓*
