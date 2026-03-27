# Câu Hỏi Bảo Vệ Đồ Án — SplitPal

Tài liệu này tổng hợp **toàn bộ các câu hỏi** mà hội đồng giảng viên có thể đặt ra khi bảo vệ đề tài **SplitPal** — ứng dụng quản lý và chia sẻ chi phí nhóm.

> **Stack chính:** Flutter (Mobile) · Node.js/TypeScript/Express (Backend) · MongoDB (Database) · Redis (Cache + Rate‑limit) · Socket.IO (Real‑time) · Firebase FCM (Push) · VNPay (Payment) · Gemini Vision API (OCR)

---

## Mục Lục

1. [Tổng Quan & Kiến Trúc Hệ Thống](#1-tổng-quan--kiến-trúc-hệ-thống)
2. [Xác Thực & Bảo Mật](#2-xác-thực--bảo-mật)
3. [Quản Lý Nhóm & Phân Quyền](#3-quản-lý-nhóm--phân-quyền)
4. [Quản Lý Hóa Đơn & Chia Chi Phí](#4-quản-lý-hóa-đơn--chia-chi-phí)
5. [Thuật Toán Tối Ưu Thanh Toán Nợ](#5-thuật-toán-tối-ưu-thanh-toán-nợ)
6. [Ví Điện Tử & Thanh Toán VNPay](#6-ví-điện-tử--thanh-toán-vnpay)
7. [Subscription (Đăng Ký Chi Phí Định Kỳ)](#7-subscription-đăng-ký-chi-phí-định-kỳ)
8. [Real‑time & Thông Báo](#8-realtime--thông-báo)
9. [Caching & Hiệu Năng](#9-caching--hiệu-năng)
10. [Database Design](#10-database-design)
11. [Kiến Trúc Phần Mềm & Clean Code](#11-kiến-trúc-phần-mềm--clean-code)
12. [Testing & Deployment](#12-testing--deployment)
13. [Xử Lý Lỗi & Edge Cases](#13-xử-lý-lỗi--edge-cases)
14. [Distributed Systems & Concurrency](#14-distributed-systems--concurrency)
15. [Quyết Định Thiết Kế & Cải Tiến](#15-quyết-định-thiết-kế--cải-tiến)
16. [Câu Hỏi Nâng Cao](#16-câu-hỏi-nâng-cao)

---

## 1. Tổng Quan & Kiến Trúc Hệ Thống

**Q1. SplitPal giải quyết bài toán gì trong thực tế? Cho ví dụ cụ thể.**

> Gợi ý: nhóm bạn đi du lịch, một người trả trước toàn bộ chi phí (phòng khách sạn, ăn uống) → hệ thống tự tính mỗi người nợ bao nhiêu → thành viên thanh toán qua ví nội bộ hoặc VNPay → nợ tự động giảm.

---

**Q2. Mô tả kiến trúc tổng thể. Dữ liệu đi từ người dùng đến database theo luồng nào?**

> Gợi ý:
> ```
> Flutter App
>   → REST API (Express/TypeScript, port 3000)
>     → MongoDB (lưu trữ chính)
>     → Redis (cache JSON responses + rate‑limit + OTP)
>   ← Socket.IO (real‑time chat + notification)
>   ← Firebase FCM (push notification mobile)
>   → VNPay (redirect thanh toán)
>   → SMTP (email OTP, welcome)
>   → Gemini Vision API (OCR hóa đơn)
>   → exchangerate-api.com (tỷ giá ngoại tệ)
> ```

---

**Q3. Tại sao chọn Flutter thay vì React Native hay native iOS/Android?**

> Gợi ý: single codebase cho iOS + Android + Web; Dart type‑safe; widget system nhất quán; hot reload khi dev. Nhược: AOT binary lớn hơn, ecosystem nhỏ hơn React Native.

---

**Q4. Tại sao backend dùng Node.js/TypeScript thay vì Go, Java Spring hoặc Python Django?**

> Gợi ý: non‑blocking I/O phù hợp real‑time (Socket.IO); TypeScript giảm runtime error; npm ecosystem phong phú; cùng ngôn ngữ JS với Flutter dev (Dart tương tự cú pháp). Nhược: single‑threaded CPU‑bound tasks.

---

**Q5. Render.com được dùng để deploy như thế nào? `render.yaml` cấu hình gì?**

> Gợi ý: Web Service Node.js; environment variables (MongoDB URI, Redis URL, JWT Secret, VNPay keys, Firebase JSON); auto‑deploy khi push lên branch main.

---

## 2. Xác Thực & Bảo Mật

**Q6. Mô tả luồng đăng ký tài khoản từ đầu đến cuối. Tại sao cần xác thực email?**

> Gợi ý:
> 1. `POST /auth/signup` → tạo User với `status: 'inactive'`
> 2. Gửi OTP 6 số qua email (lưu trong Redis với TTL)
> 3. `POST /auth/verify-otp` → kiểm tra OTP → set `status: 'active'`
> 4. Gửi welcome email
>
> Lý do xác thực email: ngăn tài khoản giả, đảm bảo email thực sự tồn tại để gửi OTP thanh toán.

---

**Q7. Nếu user đăng ký lần 2 với email đã tồn tại nhưng chưa active, hệ thống xử lý thế nào?**

> Gợi ý: `authService.SignUpUser()` kiểm tra `existingUser.status === 'inactive'` → cập nhật passwordHash + displayName → gửi lại OTP (không tạo user mới). Tránh tích lũy user inactive trong DB.

---

**Q8. JWT hoạt động thế nào trong hệ thống? Token hết hạn thì sao?**

> Gợi ý: `expiresIn: '7d'`; payload gồm `{ userId, email }`; `authMiddleware` verify token trên mọi protected route; khi hết hạn → 401 → Flutter redirect về login. Không có refresh token — ưu/nhược?

---

**Q9. Two‑Factor Authentication (2FA) hoạt động thế nào? Giải thích TOTP.**

> Gợi ý:
> - Setup: `speakeasy.generateSecret()` → lưu `twoFactorSecret` (base32) vào User; tạo QR code URI → user quét bằng Google Authenticator
> - Verify: `speakeasy.totp.verify()` với `window: 2` (±60 giây drift)
> - Backup codes: 8 mã hex 8 ký tự, bcrypt‑hashed, dùng một lần
> - Guard: `twoFactorService.verify2FAIfEnabled()` được gọi trước các thao tác nhạy cảm

---

**Q10. Backup codes trong 2FA được tạo và lưu trữ như thế nào? Tại sao phải hash?**

> Gợi ý: `crypto.randomBytes(4).toString('hex')` → 8 ký tự hex → `bcrypt.hash(code, 10)` → lưu mảng hash vào `twoFactorBackupCodes`. Hash để nếu DB bị lộ thì kẻ tấn công không dùng được backup code.

---

**Q11. Rate limiting bảo vệ API như thế nào? Cơ chế fallback khi Redis down?**

> Gợi ý:
> - Redis: `INCR key` + `PEXPIRE key windowMs` → nếu count > max → 429 + `Retry-After` header
> - Fallback: in‑memory `Map<string, {count, resetAt}>` trong process Node.js
> - Nhược của fallback: không share state giữa nhiều Node.js instances (horizontal scale)

---

**Q12. OTP cho email được lưu ở đâu? Tại sao dùng Redis thay vì MongoDB?**

> Gợi ý: Redis với TTL tự động xóa sau khi hết hạn; read/write O(1); không cần persistence lâu dài; tránh bloat collection MongoDB.

---

**Q13. Xác thực VNPay IPN (callback) được bảo mật thế nào?**

> Gợi ý: mọi request từ VNPay đều kèm `vnp_SecureHash` = HMAC‑SHA512 của các params (đã sort alphabetically) với `VNPAY_HASH_SECRET`; server tính lại hash và so sánh → reject nếu không khớp.

---

**Q14. Có những lỗ hổng bảo mật tiềm năng nào trong hệ thống hiện tại?**

> Gợi ý:
> - OTP 6 số random (không phải HMAC‑OTP) → dễ brute‑force nếu rate limit bị bypass
> - JWT không có refresh token → không thể revoke trước khi hết hạn
> - `twoFactorSecret` lưu plain text trong MongoDB → nên encrypt at rest
> - `DEFAULT_WITHDRAWAL_BANK` hardcode trong code → không linh hoạt cho production

---

## 3. Quản Lý Nhóm & Phân Quyền

**Q15. Ba role trong nhóm khác nhau thế nào về quyền hạn?**

| Role | Quyền |
|------|-------|
| OWNER | Tạo nhóm, xóa nhóm (soft delete), nâng/hạ ADMIN, mời thành viên, tạo PaymentRequest, mọi quyền ADMIN |
| ADMIN | Tạo/hủy PaymentRequest, quản lý invoice (lock/unlock), mời thành viên |
| USER | Xem nhóm, tạo invoice, thanh toán transfer của mình |

---

**Q16. Tại sao Group dùng soft delete (`deletedAt`) thay vì hard delete?**

> Gợi ý:
> - Giữ lại lịch sử invoice, debt, transaction để audit
> - `groupDeleted = true` trên Invoice và Subscription → vẫn hiển thị lịch sử nhưng ngăn action mới
> - Không bị lỗi khi query `referenceId` của Transaction trỏ về group đã xóa

---

**Q17. Invite thành viên vào nhóm hoạt động thế nào? Token có thời hạn không?**

> Gợi ý: `crypto.randomUUID()` token → lưu vào `Invite` collection với `expiredAt`; gửi link qua email; user click → `POST /groups/invite/accept` → kiểm tra token + status PENDING + chưa expired → tạo GroupMember.

---

**Q18. Khi thành viên rời nhóm (`leftAt` được set), dữ liệu nợ xử lý thế nào?**

> Gợi ý: `OriginalDebt` vẫn tồn tại với `remainingAmount > 0`; hệ thống vẫn cho phép thanh toán; GroupMember query dùng `leftAt: null` để tìm thành viên active nhưng debt không lọc theo `leftAt` → cần thảo luận về business rule này.

---

## 4. Quản Lý Hóa Đơn & Chia Chi Phí

**Q19. Hệ thống hỗ trợ mấy loại chia chi phí? Giải thích từng loại với ví dụ.**

> | Split Type | Giải thích | Ví dụ |
> |-----------|-----------|-------|
> | EQUAL | Chia đều cho tất cả assignedTo | 300k / 3 người = 100k mỗi người |
> | PERCENTAGE | Mỗi người một % khác nhau | A:50%, B:30%, C:20% của 300k |
> | CUSTOM | Số tiền cụ thể từng người | A:150k, B:100k, C:50k |
> | WEIGHT | Tỷ lệ trọng số | A:2, B:1, C:1 → A:150k, B:75k, C:75k |

---

**Q20. Validation nào được thực hiện trong `validateItemSplits()`?**

> Gợi ý:
> - EQUAL: không cần splits array, return sớm
> - PERCENTAGE: tổng % phải = 100 ± 0.01; mọi user trong `assignedTo` phải có entry
> - CUSTOM: tổng custom amounts phải = `item.amount` ± 0.01
> - WEIGHT: mọi weight phải > 0

---

**Q21. Multi‑currency hoạt động thế nào khi group có baseCurrency = VND nhưng invoice đơn vị USD?**

> Gợi ý:
> 1. Gọi `exchangeRateService.getRate('USD', 'VND')` → ví dụ 25,400
> 2. Lưu vào Invoice: `exchangeRate = 25400`, `convertedAmountTotal = amountTotal * 25400`, `baseCurrency = 'VND'`
> 3. OriginalDebt lưu thêm: `originalCurrency = 'USD'`, `originalAmountInCurrency`, `exchangeRateUsed`, `rateLockedAt`
> 4. Mọi tính toán settlement dùng VND (baseCurrency)

---

**Q22. Tại sao tỷ giá phải "lock" tại thời điểm tạo invoice? Nếu không lock thì gì xảy ra?**

> Gợi ý: nếu không lock → khi payment request được tạo 1 tuần sau, tỷ giá đổi → tổng debt thay đổi → không khớp với số tiền thực tế đã chia → user bị thiệt hoặc lợi bất hợp lý. Lock đảm bảo fairness.

---

**Q23. Tỷ giá được lấy từ đâu? Có fallback không?**

> Gợi ý: exchangerate‑api.com (free tier); cache Redis 1 giờ; fallback static rates hardcode trong `STATIC_RATES_TO_VND` (VND, USD, EUR, GBP, JPY, v.v.) → nếu API lỗi vẫn hoạt động được.

---

**Q24. OCR hóa đơn bằng Gemini Vision API hoạt động thế nào? Kết quả sai thì xử lý thế nào?**

> Gợi ý: Flutter chụp ảnh hóa đơn → encode base64 → gửi lên Gemini API với prompt extract items/amounts → parse JSON response → điền sẵn vào form. Nếu sai → user chỉnh sửa thủ công trước khi submit.

---

**Q25. Invoice có thể điều chỉnh sau khi đã locked không? Luồng adjustment?**

> Gợi ý: tạo invoice mới với `isAdjustment = true` và `originalInvoiceId` trỏ về invoice gốc; invoice gốc vẫn giữ nguyên (audit trail); adjustment invoice tạo OriginalDebt mới → được tính vào PaymentRequest tiếp theo.

---

**Q26. Luồng tạo invoice hoàn chỉnh: từ lúc user upload đến khi OriginalDebt được tạo?**

> Gợi ý:
> 1. `POST /invoices` → validate group membership + splits
> 2. Tạo `Invoice` document
> 3. Tạo các `InvoiceItem` documents
> 4. `calculateShareForUser()` cho từng item theo splitType
> 5. Tổng hợp nợ theo cặp (debtor → creditor)
> 6. Tạo `OriginalDebt` cho mỗi cặp (nếu currency khác VND → lock tỷ giá)
> 7. Gửi notification `INVOICE_CREATED` đến thành viên nhóm
> 8. Invalidate Redis cache invoice của group

---

## 5. Thuật Toán Tối Ưu Thanh Toán Nợ

**Q27. Hệ thống sử dụng những thuật toán nào để tính toán transfers? Khi nào dùng thuật toán nào?**

> Gợi ý:
> - **Greedy**: sort debtors + creditors giảm dần → ghép lớn nhất trước → tối thiểu số transfer
> - **MinCostFlow**: khi có ít nhất 1 cặp (A, B) mutual debts → netoff trước → phần còn lại dùng Greedy
> - `hasMutualDebts()` auto‑detect → chọn strategy phù hợp

---

**Q28. Giải thích thuật toán Greedy Settlement bằng ví dụ cụ thể.**

> Ví dụ: A nợ net -150k, B nợ net -100k, C nhận +200k, D nhận +50k
> - Sort debtors: [A=150k, B=100k]; creditors: [C=200k, D=50k]
> - Ghép A(150k) ↔ C(200k): min(150,200)=150 → A trả C 150k; C còn 50k
> - Ghép B(100k) ↔ C(50k): min(100,50)=50 → B trả C 50k; B còn 50k
> - Ghép B(50k) ↔ D(50k): B trả D 50k
> - Kết quả: 3 transfers (tối ưu)

---

**Q29. MinCostFlow Settlement hoạt động thế nào? Cho ví dụ netoff.**

> Ví dụ: A nợ B 100k, B nợ A 60k (mutual debt)
> - `pairNet[A][B] = 100k`, `pairNet[B][A] = 60k`
> - Netoff: `net = 100 - 60 = 40` → `pairNet[A][B] = 40`, `pairNet[B][A] = 0`
> - Kết quả: chỉ cần 1 transfer A→B 40k thay vì 2 transfers (A→B 100k + B→A 60k)

---

**Q30. `hasMutualDebts()` hoạt động thế nào? Độ phức tạp?**

> Gợi ý:
> ```typescript
> const pairs = new Set(rawDebts.map(d => `${d.debtorId}:${d.creditorId}`));
> for (const debt of rawDebts) {
>     if (pairs.has(`${debt.creditorId}:${debt.debtorId}`)) return true;
> }
> return false;
> ```
> O(n) với n = số raw debts. Build Set O(n) + scan O(n) = O(n).

---

**Q31. Debt Allocation (FIFO) là gì? Tại sao cần mapping transfer về OriginalDebt?**

> Gợi ý: `allocateDebtsForTransfer()` sort OriginalDebt theo `createdAt ASC` (FIFO = trả nợ cũ nhất trước) → tạo `TransferDebtAllocation` records → khi transfer COMPLETED → `remainingAmount` trên từng OriginalDebt giảm chính xác → audit trail rõ ràng.

---

**Q32. Khi chạy settlement engine, tổng nợ tính toán không khớp với OriginalDebt trong DB, lỗi gì xảy ra?**

> Gợi ý: `allocateDebtsForTransfer()` throw `Error('Cannot allocate X VND. Only Y VND available...')` → transaction abort → PaymentRequest creation fail → log error để debug data inconsistency.

---

**Q33. PaymentRequest có thể tạo khi đã có một request đang ISSUED không?**

> Gợi ý: không — `paymentRequestService.createPaymentRequest()` check `PaymentRequest.findOne({ groupId, status: { $in: ['ISSUED', 'PARTIALLY_PAID'] } })` bên trong session → throw error. Còn dùng distributed lock (`acquireLock`) để tránh race condition tạo đồng thời.

---

## 6. Ví Điện Tử & Thanh Toán VNPay

**Q34. Luồng nạp tiền (top‑up) qua VNPay từ đầu đến cuối?**

> Gợi ý:
> 1. `POST /vnpay/top-up` → tạo `TopUp` status PENDING → build VNPay URL (HMAC-SHA512)
> 2. Flutter mở WebView/redirect tới VNPay
> 3. User thanh toán → VNPay gọi `GET /vnpay/return` (return URL)
> 4. VNPay gọi `POST /vnpay/ipn` (IPN) → verify `vnp_SecureHash` → `accountService.completeTopUp()` → `$inc balance`
> 5. Tạo Transaction `TOP_UP` với balanceBefore/After
> 6. Gửi notification `BALANCE_UPDATED`

---

**Q35. Idempotency trong xử lý VNPay callback được đảm bảo thế nào? Tại sao quan trọng?**

> Gợi ý: `findOneAndUpdate({ _id: topUpId, status: 'PENDING' }, ...)` — nếu TopUp đã COMPLETED thì `updatedTopUp === null` → skip, không credit lần 2. VNPay có thể gọi IPN nhiều lần nếu không nhận được response → phải idempotent.

---

**Q36. Luồng transfer (thanh toán nợ giữa thành viên) hoạt động thế nào? OTP có vai trò gì?**

> Gợi ý:
> 1. `POST /transfers/{id}/initiate` → check balance → generate OTP 6 số → lưu `otp` + `otpExpiresAt` (5 phút) → gửi email
> 2. `POST /transfers/{id}/verify-otp` → verify OTP + MongoDB transaction: update Transfer COMPLETED + deduct fromUser balance + add toUser balance + reduce OriginalDebt
> 3. Tạo 2 Transaction records (SENT + RECEIVED)
> 4. Gửi notification PAYMENT_RECEIVED

---

**Q37. MongoDB transaction trong `verifyOTPAndPay()` bảo vệ điều gì?**

> Gợi ý: `findOneAndUpdate({ _id: transferId, status: 'PENDING', otp, otpExpiresAt: { $gt: now } })` — nếu transfer đã COMPLETED (do concurrent request) → `lockedTransfer === null` → abort. `findOneAndUpdate({ _id: userId, balance: { $gte: amount } })` — nếu balance không đủ → null → abort. Atomicity đảm bảo không bao giờ deduct balance nếu transfer fail.

---

**Q38. Luồng withdrawal (rút tiền) có bao nhiêu bước? Tại sao cần OTP?**

> Gợi ý:
> 1. `POST /withdrawals` → tạo Withdrawal `OTP_SENT` → gửi OTP email (10 phút)
> 2. `POST /withdrawals/{id}/verify-otp` → MongoDB transaction: set COMPLETED + `$inc balance -amount` + tạo Transaction `WITHDRAWAL`
>
> OTP bảo vệ: nếu tài khoản bị hack qua token đánh cắp → kẻ tấn công không thể rút tiền vì không có OTP email.

---

**Q39. Transaction history lưu những gì? Tại sao là immutable?**

> Gợi ý: `{ userId, type, amount, balanceBefore, balanceAfter, currency, description, referenceId, referenceType, createdAt }`; `timestamps: { createdAt: true, updatedAt: false }` → không có updatedAt → không thể sửa. Đây là audit log tài chính — immutability là yêu cầu bắt buộc.

---

**Q40. Các loại TransactionType có trong hệ thống là gì?**

> Gợi ý: `TOP_UP | WITHDRAWAL | TRANSFER_SENT | TRANSFER_RECEIVED | TRANSFER_REFUND_SENT | TRANSFER_REFUND_RECEIVED | VNPAY_PAYMENT | EXPENSE_PAYMENT | SUBSCRIPTION_FEE | REFUND | SETTLEMENT_SENT | SETTLEMENT_RECEIVED`

---

## 7. Subscription (Đăng Ký Chi Phí Định Kỳ)

**Q41. Subscription hoạt động thế nào? Ai được charge và khi nào?**

> Gợi ý: OWNER/ADMIN tạo Subscription với `amount`, `billingCycle` (WEEKLY/MONTHLY/YEARLY), `nextBillingDate`; scheduler (cron mỗi giờ) check `nextBillingDate <= now && status = ACTIVE` → charge từng `SubscriptionMember` `shareAmount = amount / activeMemberCount` → tạo Transaction `SUBSCRIPTION_FEE` → update `nextBillingDate` → lưu `BillingHistory`.

---

**Q42. Scheduler được implement thế nào? Tại sao chọn interval 1 giờ?**

> Gợi ý: `setInterval(runJob, 60*60*1000)` + `setTimeout(runJob, 5000)` khi startup (delay để chờ DB connect); không dùng cron‑based scheduler (node-cron) để đơn giản hóa. 1 giờ: billing thường daily/weekly/monthly → 1 giờ đủ chính xác, không cần run mỗi phút.

---

**Q43. Retry logic khi charge thất bại (member không đủ số dư) là gì?**

> Gợi ý: `retryCount++`, `failureReason = 'Insufficient balance'`, `lastAttemptAt = now`, status → `PAST_DUE` sau N lần thất bại; gửi notification `SUBSCRIPTION_BILLING_FAILED`; retry lần tiếp ở chu kỳ sau.

---

**Q44. BillingHistory lưu những thông tin gì? Mục đích?**

> Gợi ý: `{ subscriptionId, groupId, billingDate, amount, status (SUCCESS/FAILED/PARTIAL), membersCharged, membersFailed, totalCollected, memberResults[{userId, shareAmount, success, reason}] }`; cho phép admin xem ai đã trả, ai không đủ số dư.

---

**Q45. Edge case: subscription MONTHLY ngày 31/1 → nextBillingDate là ngày nào?**

> Gợi ý: `next.setMonth(next.getMonth() + 1)` trên date 31/1 → JavaScript tự overflow → 3/3 (vì tháng 2 không có ngày 31). Đây là behavior của JS Date — có thể coi là bug (expected: 28/2 hoặc cuối tháng 2). Cần thảo luận về fix.

---

## 8. Real‑time & Thông Báo

**Q46. Socket.IO được dùng để làm gì? Authentication qua WebSocket hoạt động thế nào?**

> Gợi ý: real‑time group chat + notification push. Middleware: lấy token từ `socket.handshake.auth.token` → `jwt.verify()` → attach `socket.userId`; auto‑join room `user:{userId}` khi connect → notification gửi trực tiếp tới room này.

---

**Q47. Hệ thống có bao nhiêu loại Notification? Liệt kê và giải thích vai trò.**

> Gợi ý (13 loại):
> `EXPENSE_CREATED, EXPENSE_UPDATED, INVOICE_CREATED, SETTLEMENT_CREATED, PAYMENT_RECEIVED, INVITE_RECEIVED, GROUP_JOINED, BALANCE_UPDATED, PAYMENT_REQUEST_CANCELLED, PAYMENT_REFUNDED, SUBSCRIPTION_BILLING_SUCCESS, SUBSCRIPTION_BILLING_FAILED, SUBSCRIPTION_CANCELLED`

---

**Q48. Push notification (FCM) hoạt động thế nào? `fcmToken` được lưu ở đâu?**

> Gợi ý: Flutter app lấy FCM token từ Firebase SDK → gửi lên `PUT /account/fcm-token` → lưu vào `User.fcmToken`; khi cần push → `admin.messaging().send({ token: user.fcmToken, notification: {...} })`; `pushNotificationsEnabled` flag cho user tắt push.

---

**Q49. Nếu FCM token expired/invalid, hệ thống xử lý thế nào?**

> Gợi ý: Firebase trả error `messaging/registration-token-not-registered` → nên catch và set `user.fcmToken = null` trong DB → tránh spam request lỗi tới Firebase. Hiện tại code có thể chưa handle case này → điểm cải tiến.

---

**Q50. Email được gửi trong những trường hợp nào? Bảo mật SMTP credentials thế nào?**

> Gợi ý: OTP đăng ký, OTP transfer, OTP withdrawal, welcome email, invite link; credentials trong `.env` (`SMTP_HOST, SMTP_USER, SMTP_PASS`) → không commit vào git (`.gitignore`).

---

## 9. Caching & Hiệu Năng

**Q51. Redis được sử dụng cho những mục đích gì trong SplitPal?**

> | Mục đích | Key Pattern | TTL |
> |----------|------------|-----|
> | Cache JSON response | `splitpal:cache:invoice:{groupId}:list:{userId}:{status}` | 45-60s |
> | Rate limiting | `splitpal:ratelimit:{prefix}:{ip}` | windowMs |
> | OTP email | (trong emailService) | 5-10 phút |
> | Exchange rates | `splitpal:exchange:rates_to_vnd` | 1 giờ |
> | Distributed lock | `splitpal:lock:{name}:{groupId}` | 10-15s |

---

**Q52. Cache invalidation được thực hiện khi nào? Chiến lược là gì?**

> Gợi ý: write‑through invalidation — sau khi create/update/delete → gọi `deleteKeysByPrefix(buildRedisKey('cache', 'invoice', groupId))` → xóa toàn bộ cache cho group đó; TTL-based expiry là backstop. Vì data thay đổi không thường xuyên, TTL 45-60s là trade‑off tốt.

---

**Q53. Redis key naming convention là gì? Tại sao dùng prefix `splitpal:`?**

> Gợi ý: `splitpal:{namespace}:{...segments}` — `buildRedisKey(...parts)` join bằng `:` + sanitize; prefix `splitpal` isolate với các app khác trên cùng Redis instance (env `REDIS_PREFIX`).

---

**Q54. Điều gì xảy ra khi Redis hoàn toàn không khả dụng (`REDIS_URL` không set)?**

> Gợi ý:
> - Cache: miss → query MongoDB trực tiếp (slow nhưng vẫn hoạt động)
> - Rate limit: fallback in‑memory Map
> - Lock: fallback MongoDB Lock collection (TTL index tự cleanup)
> - OTP: emailService có thể bị ảnh hưởng → cần check implementation

---

**Q55. Distributed lock được dùng ở đâu? Tại sao cần?**

> Gợi ý: `acquireLock('payment_request', groupId)` trước khi tạo PaymentRequest → tránh race condition khi 2 admin cùng click "tạo payment request" → chỉ 1 request thành công; lock tự expire sau 10s (TTL); fallback Mongo lock nếu Redis down.

---

## 10. Database Design

**Q56. Tại sao chọn MongoDB thay vì PostgreSQL?**

> Gợi ý:
> - Invoice items có structure linh hoạt (splits array khác nhau mỗi item)
> - Schema ít JOIN phức tạp ở thời điểm đầu
> - Horizontal scale dễ hơn
>
> Nhược điểm:
> - Không có foreign key constraints → data integrity phải enforce ở application layer
> - Transaction hỗ trợ (4.0+) nhưng kém efficient hơn PostgreSQL ACID
> - Không có JOIN native → phải `populate()` hoặc `$lookup` aggregation

---

**Q57. Indexing strategy trong hệ thống thế nào? Cho 3 ví dụ và giải thích tại sao.**

> Gợi ý:
> 1. `Transaction: { userId: 1, createdAt: -1 }` — query history theo user, sort mới nhất trước → compound index hiệu quả
> 2. `Invoice: { groupId: 1, status: 1 }` — filter invoice theo group và trạng thái → 2 field hay dùng cùng nhau
> 3. `OriginalDebt: { groupId: 1, debtorId: 1 }` và `{ remainingAmount: 1 }` — tìm debt chưa thanh toán trong group

---

**Q58. Giải thích chuỗi data model từ tạo invoice đến hoàn thành thanh toán.**

> ```
> User tạo Invoice
>   └─ InvoiceItem[] (mỗi item có splitType + splits)
>        └─ OriginalDebt[] (nợ gốc theo cặp debtor→creditor, remainingAmount)
>             └─ [OWNER tạo PaymentRequest]
>                  └─ Transfer[] (tối ưu hóa bởi DebtSettlementEngine)
>                       └─ TransferDebtAllocation[] (FIFO allocation)
>                            └─ [User pay → OTP verify]
>                                 └─ OriginalDebt.remainingAmount giảm
>                                      └─ Transaction[] (audit log)
> ```

---

**Q59. Tại sao `Transaction` không có `updatedAt` nhưng các model khác có?**

> Gợi ý: `timestamps: { createdAt: true, updatedAt: false }` — Transaction là immutable financial audit log. Nếu có lỗi → tạo correction Transaction mới, không sửa record cũ. Principle: ledger entries không được xóa hoặc sửa.

---

**Q60. Lock model (`locks` collection) dùng để làm gì? TTL index hoạt động thế nào?**

> Gợi ý: MongoDB fallback distributed lock; `LockSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 })` → MongoDB background job xóa document có `expiresAt <= now`; unique index `{ name: 1, groupId: 1 }` enforce chỉ 1 lock per key; `findOneAndUpdate` với upsert + filter `expiresAt <= now` là atomic.

---

## 11. Kiến Trúc Phần Mềm & Clean Code

**Q61. Flutter app được tổ chức theo pattern nào?**

> Gợi ý: Clean Architecture + Feature‑First:
> ```
> lib/
>   features/
>     auth/
>       data/         ← repositories impl, datasources, models
>       domain/       ← entities, repository interfaces, use cases
>       presentation/ ← pages, widgets, providers
>     groups/ invoices/ ...
>   core/
>     di/        ← GetIt dependency injection
>     network/   ← Dio HTTP client
>     error/     ← Either<Failure, T> error handling
>     widgets/   ← shared UI components
> ```

---

**Q62. Dependency Injection được thực hiện thế nào trên Flutter?**

> Gợi ý: `get_it` package — `GetIt.instance.registerLazySingleton<GroupRepository>(() => GroupRepositoryImpl(...))` trong `core/di/`; inject vào Provider/UseCase qua `getIt<GroupRepository>()`; loosely coupled, dễ mock khi test.

---

**Q63. Error handling trên Flutter sử dụng pattern gì?**

> Gợi ý: `dartz` package — `Either<Failure, T>`; repository trả `Left(Failure)` hoặc `Right(data)`; presentation layer fold để handle; tránh exception propagation không kiểm soát.

---

**Q64. Service layer trên backend tách biệt với Controller thế nào?**

> Gợi ý: Controller chỉ: parse request params → gọi service → format response → trả HTTP status. Service chứa: business logic, DB queries, cache, notification. Lợi ích: testable (mock DB), reusable (service gọi service), maintainable.

---

**Q65. State management trên Flutter dùng gì? So sánh với BLoC và Riverpod.**

> Gợi ý: `Provider` package — đủ dùng cho scale hiện tại, API đơn giản; BLoC: boilerplate nhiều hơn nhưng tốt cho complex event‑driven flow; Riverpod: type‑safe hơn Provider, auto‑dispose, code generation — nâng cấp tốt nếu app lớn hơn.

---

## 12. Testing & Deployment

**Q66. Hệ thống có những loại test nào?**

> Gợi ý:
> - `scripts/concurrency-smoke.ts`: smoke test concurrent transfers (race condition)
> - `mongodb-memory-server` trong devDependencies: in‑memory MongoDB cho unit test
> - Flutter `test/`: widget tests cơ bản
> - Thiếu: integration tests, e2e tests, load tests

---

**Q67. Concurrency smoke test kiểm tra điều gì cụ thể? Tại sao quan trọng?**

> Gợi ý: simulate N users đồng thời gọi `verifyOTPAndPay()` cho cùng 1 transfer → kiểm tra chỉ 1 transfer COMPLETED, balance không bị deduct nhiều lần (double‑spend prevention); MongoDB transaction + `findOneAndUpdate` với status filter là key guard.

---

**Q68. Các environment variables quan trọng nào cần có cho production?**

> | Variable | Mục đích |
> |---------|---------|
> | `JWT_SECRET` | Ký JWT (>=256 bit random) |
> | `MONGODB_URI` | MongoDB Atlas connection string |
> | `REDIS_URL` | Redis connection (Upstash/Redis Cloud) |
> | `VNPAY_TMN_CODE` | 8 ký tự alphanumeric từ VNPay merchant |
> | `VNPAY_HASH_SECRET` | HMAC key cho signature |
> | `FIREBASE_SERVICE_ACCOUNT_JSON` | Firebase Admin SDK credentials |
> | `SMTP_HOST/USER/PASS` | Email provider credentials |

---

**Q69. Làm thế nào để scale hệ thống khi người dùng tăng?**

> Gợi ý:
> - **Horizontal scale Node.js**: nhiều instances + load balancer; Redis phải share (không dùng in‑memory fallback)
> - **MongoDB**: replica set + read preference secondary; sharding khi cần
> - **File uploads**: hiện lưu local `uploads/` → cần chuyển sang S3/Cloudinary
> - **Scheduler**: chạy nhiều instances → cần distributed lock để tránh double‑charge subscription

---

## 13. Xử Lý Lỗi & Edge Cases

**Q70. Điều gì xảy ra nếu tạo PaymentRequest khi không có invoice nào SUBMITTED?**

> Gợi ý: `invoices.length === 0` → throw `Error('No submitted invoices found...')` → client nhận 400. Không tạo empty PaymentRequest.

---

**Q71. Khi PaymentRequest bị CANCEL, các Transfer liên quan xử lý thế nào?**

> Gợi ý: Transfer status → CANCELLED; Invoice isLocked → false, status → SUBMITTED (trả về pool để tạo request mới); OriginalDebt `remainingAmount` không thay đổi (transfer chưa COMPLETED nên chưa reduce). `filterCancelledTransferDebts()` xử lý edge case này.

---

**Q72. `filterCancelledTransferDebts()` làm gì? Tại sao cần?**

> Gợi ý: khi tất cả transfers của một OriginalDebt đều CANCELLED và invoice đã trở về SUBMITTED → debt vẫn valid, được tính vào request tiếp theo; nếu invoice không còn SUBMITTED/LOCKED → loại debt này khỏi kết quả để tránh double‑count.

---

**Q73. Nếu user tạo invoice với `amountTotal = 0`, hệ thống xử lý thế nào?**

> Gợi ý: kiểm tra validation trong service; nếu invoice items tổng = 0 → không tạo OriginalDebt nào → invoice vẫn tồn tại nhưng không ảnh hưởng settlement.

---

**Q74. Nếu group bị xóa (soft delete) trong khi có PaymentRequest đang ISSUED, xử lý thế nào?**

> Gợi ý: `groupDeleted = true` trên Invoice và Subscription; cần thảo luận liệu có cancel PaymentRequest tự động không, hay để user tự cancel.

---

**Q75. Race condition khi 2 người cùng lúc thanh toán cùng 1 transfer?**

> Gợi ý: `findOneAndUpdate({ _id: transferId, status: 'PENDING', otp, otpExpiresAt: {$gt: now} }, { status: 'COMPLETED' })` là atomic — chỉ 1 request đổi status thành công; request thứ 2 nhận `lockedTransfer === null` → throw "Already processed". MongoDB document‑level locking đảm bảo điều này.

---

## 14. Distributed Systems & Concurrency

**Q76. Distributed lock được implement thế nào? Tại sao cần 2 tầng (Redis + MongoDB)?**

> Gợi ý:
> - **Redis lock** (primary): `SET key token PX ttl NX` — atomic; Lua script để release đúng token; nhanh (in-memory)
> - **MongoDB lock** (fallback): `findOneAndUpdate` upsert với filter `expiresAt <= now` — atomic; chậm hơn nhưng persistent
> - 2 tầng: Redis là best‑effort performance; Mongo là safety net khi Redis down

---

**Q77. MongoDB transaction trong hệ thống được dùng ở đâu? Tại sao?**

> Gợi ý: `verifyOTPAndPay()`, `verifyOTP()` (withdrawal), `completeTopUp()`, `createPaymentRequest()` — tất cả thao tác chuyển tiền. `session.withTransaction()` tự retry khi có transient errors; `abortTransaction()` khi có lỗi → rollback toàn bộ.

---

**Q78. Nếu server crash sau khi deduct balance nhưng trước khi tạo Transaction record, xử lý thế nào?**

> Gợi ý: nếu dùng `session.withTransaction()` → cả `$inc balance` và `createTransaction` phải cùng session → atomicity; trong `transferService.verifyOTPAndPay()`, `createTransaction` được gọi SAU khi session kết thúc → đây là potential inconsistency! Điểm cải tiến: đưa `createTransaction` vào trong session.

---

## 15. Quyết Định Thiết Kế & Cải Tiến

**Q79. Tại sao dùng Socket.IO thay vì WebSocket thuần hay Server‑Sent Events?**

> Gợi ý: Socket.IO có auto‑fallback polling (hữu ích khi WebSocket bị block), room management built‑in, middleware authentication, reconnection logic tự động. Nhược: overhead protocol, bundle size lớn hơn.

---

**Q80. Tại sao không có refresh token? Ưu và nhược điểm?**

> Gợi ý: đơn giản hóa implementation; nhược: không thể revoke token trước khi hết hạn (7 ngày) — nếu token bị đánh cắp → kẻ tấn công có 7 ngày; không có `jti` (JWT ID) để blacklist. Cải tiến: thêm refresh token + Redis blacklist.

---

**Q81. File upload (ảnh hóa đơn) được xử lý thế nào? Hạn chế của cách hiện tại?**

> Gợi ý: `multer` save vào local `uploads/` directory; trả về URL dạng `https://api.com/uploads/filename.jpg`. Hạn chế: không scale (mỗi server instance có folder riêng); mất file khi redeploy/restart. Cải tiến: S3, Cloudinary, hoặc GCS.

---

**Q82. Nếu phải làm lại từ đầu, bạn thay đổi gì?**

> Gợi ý (mở):
> - Refresh token + token revocation
> - Message queue (Bull/BullMQ) thay scheduler đơn giản → reliable, retryable jobs
> - GraphQL subscriptions thay Socket.IO (nếu không cần chat)
> - Unit test coverage > 80%
> - S3 cho file uploads
> - `argon2` thay `bcrypt`
> - Encrypt sensitive fields (twoFactorSecret) at rest

---

## 16. Câu Hỏi Nâng Cao

**Q83. Giải thích cơ chế ký VNPay: `buildSignData()` và HMAC‑SHA512.**

> Gợi ý:
> 1. Filter params: loại bỏ rỗng + key bắt đầu `vnp_`
> 2. Sort alphabetically (`localeCompare`)
> 3. Encode value: `encodeURIComponent(value).replace(/%20/g, '+')`
> 4. Join: `key=value&key=value...`
> 5. `crypto.createHmac('sha512', VNPAY_HASH_SECRET).update(signData).digest('hex').toUpperCase()`

---

**Q84. TOTP (Time‑based OTP) dựa trên nguyên lý gì? Tại sao `window: 2`?**

> Gợi ý:
> - TOTP = HOTP với time step 30 giây: `TOTP = HMAC-SHA1(secret, floor(unixTime/30))`
> - `window: 2` → chấp nhận code trong khoảng ±2 steps (±60 giây) để compensate clock drift giữa server và mobile device
> - Code mới mỗi 30 giây → brute force 6 số (1M possibilities) trong window 120 giây là vô nghĩa

---

**Q85. Thuật toán MinCostFlow trong tài chính có tên gọi khác? Bài toán graph tương đương?**

> Gợi ý: "Debt simplification" / "Settling debts with minimum transactions" — bài toán min‑cost flow trên directed graph; mỗi người là node; nợ là directed edge với capacity = remainingAmount; tìm flow tối thiểu để balance mọi node. NP‑hard trong dạng tổng quát nhưng greedy đủ tốt cho số thành viên nhỏ (< 50).

---

**Q86. Tại sao `normalizeOrderInfo()` phải xử lý Unicode? VNPay giới hạn gì?**

> Gợi ý: VNPay `vnp_OrderInfo` chỉ chấp nhận ASCII; tiếng Việt có dấu (ê, ô, ă, ơ, ư + tones) → `normalize('NFD')` tách base char + combining marks → `replace(/[\u0300-\u036f]/g, '')` xóa dấu → loại ký tự đặc biệt còn lại → giới hạn 255 ký tự.

---

**Q87. `bcrypt` salt rounds = 10 có ý nghĩa gì? Nên chọn số mấy cho production?**

> Gợi ý: `2^10 = 1024` iterations; mỗi lần tăng 1 → gấp đôi thời gian hash; rounds=10 ≈ 65ms trên server hiện đại; rounds=12 ≈ 250ms → khuyến nghị cho production (balance giữa security và latency). Backup codes cũng rounds=10 — đủ vì code ngắn (8 hex chars).

---

**Q88. Giải thích sự khác biệt giữa `status: 'PARTIALLY_PAID'` và `status: 'PAID'` của PaymentRequest.**

> Gợi ý: `PARTIALLY_PAID` — ít nhất 1 transfer COMPLETED nhưng còn transfer khác chưa; `PAID` — tất cả transfers đều COMPLETED. `paymentRequestService.updateRequestStatus()` được gọi sau mỗi transfer COMPLETED để check và update trạng thái này.

---

**Q89. Tại sao `Transfer` model lưu cả `originalCurrency`, `originalAmount`, `convertedCurrency`, `exchangeRate` dù OriginalDebt đã lưu rồi?**

> Gợi ý: Transfer là denormalized snapshot tại thời điểm payment — nếu OriginalDebt bị thay đổi sau này, Transfer vẫn có đầy đủ thông tin audit; cũng phục vụ VNPay flow khi cần hiển thị currency conversion cho user.

---

**Q90. Làm thế nào để test toàn bộ luồng thanh toán end‑to‑end mà không cần VNPay sandbox thật?**

> Gợi ý: VNPay có sandbox environment; mock VNPay IPN bằng cách post trực tiếp tới `/vnpay/ipn` với đúng format + tính HMAC‑SHA512 bằng test secret key; `mongodb-memory-server` cho DB; Redis mock (ioredis-mock) hoặc dùng Redis test instance.

---

*Tài liệu được tổng hợp dựa trên toàn bộ source code hệ thống SplitPal (server/ + splitpal/).  
Chúc bảo vệ thành công! 🎓*
