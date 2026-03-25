# Câu Hỏi Bảo Vệ Đồ Án — SplitPal

Tài liệu này tổng hợp các câu hỏi mà hội đồng giảng viên có thể đặt ra khi bảo vệ đề tài **SplitPal** — ứng dụng chia sẻ chi phí nhóm (Flutter + Node.js/TypeScript + MongoDB).

---

## 1. Tổng Quan Hệ Thống

1. **Hệ thống SplitPal giải quyết bài toán gì? Đối tượng người dùng mục tiêu là ai?**
   - Gợi ý: chia hóa đơn trong nhóm bạn bè, gia đình, đồng nghiệp; theo dõi công nợ; thanh toán qua ví nội bộ hoặc VNPay.

2. **Kiến trúc tổng thể của hệ thống là gì? Hãy mô tả luồng dữ liệu từ client đến database.**
   - Gợi ý: Flutter client → REST API (Express/Node.js) + Socket.IO → MongoDB (lưu trữ) + Redis (cache/rate-limit) + Firebase (push) + VNPay (thanh toán) + SMTP (email).

3. **Tại sao bạn chọn stack Flutter + Node.js/TypeScript + MongoDB thay vì các lựa chọn khác?**
   - Gợi ý: cross-platform (iOS/Android), TypeScript type-safety, MongoDB flexible schema cho dữ liệu invoice phức tạp.

4. **Các thành phần external services nào được sử dụng và vai trò của từng thành phần?**
   - VNPay (thanh toán QR/thẻ), Firebase FCM (push notification), Nodemailer/SMTP (email OTP, welcome), Redis (cache + rate limit), Gemini Vision API (OCR hóa đơn), exchangerate-api.com (tỷ giá).

---

## 2. Xác Thực & Bảo Mật

5. **Luồng đăng ký tài khoản hoạt động như thế nào? Tại sao phải xác thực email bằng OTP?**
   - Gợi ý: tạo user với `status: 'inactive'` → gửi OTP qua email → verify OTP → `status: 'active'`; tránh tài khoản giả.

6. **JWT được sử dụng như thế nào? Token có thời hạn bao lâu? Làm thế nào để xử lý token hết hạn?**
   - Gợi ý: `expiresIn: '7d'`; khi hết hạn client phải đăng nhập lại; không có refresh token ở đây — ưu/nhược là gì?

7. **Hệ thống có hỗ trợ Two-Factor Authentication (2FA) không? Hoạt động như thế nào?**
   - Gợi ý: TOTP với `speakeasy`; QR code lưu secret vào DB; `window: 2` (±60 giây drift); 8 backup codes bcrypt-hashed; được yêu cầu cho các thao tác nhạy cảm.

8. **Mật khẩu được lưu trữ như thế nào? Tại sao dùng bcrypt thay vì MD5/SHA256?**
   - Gợi ý: `bcryptjs` với salt rounds = 10; chống rainbow table, slow-hash.

9. **Rate limiting được triển khai thế nào? Cơ chế fallback khi Redis không khả dụng là gì?**
   - Gợi ý: Redis INCR + PEXPIRE (sliding window); fallback `Map` in-memory nếu Redis lỗi; trả về 429 + `Retry-After` header.

10. **Điều gì xảy ra nếu kẻ tấn công cố đoán OTP email bằng brute-force?**
    - Gợi ý: rate limiting trên endpoint verify-OTP; OTP có TTL; có thể thảo luận về HMAC-OTP vs random OTP.

11. **Bảo mật endpoint VNPay IPN (Instant Payment Notification) như thế nào?**
    - Gợi ý: HMAC-SHA512 checksum; validate `vnp_SecureHash`; idempotency bằng `vnpayTxnRef`.

---

## 3. Quản Lý Nhóm & Phân Quyền

12. **Hệ thống phân quyền trong nhóm hoạt động ra sao? Sự khác biệt giữa OWNER, ADMIN, USER?**
    - Gợi ý: OWNER = tạo nhóm, xóa nhóm, nâng cấp ADMIN; ADMIN = tạo payment request, quản lý invoice; USER = xem, tạo invoice.

13. **Tại sao dùng soft delete cho Group thay vì hard delete?**
    - Gợi ý: `deletedAt` field; giữ lại lịch sử invoice, debt, transaction để audit; `groupDeleted` flag trên Invoice và Subscription.

14. **Khi một thành viên rời nhóm (`leftAt` được set), dữ liệu nợ của họ xử lý thế nào?**
    - Gợi ý: OriginalDebt vẫn tồn tại; cần settle trước khi rời? Hay hệ thống vẫn cho phép payment sau khi left?

15. **Cơ chế invite thành viên vào nhóm hoạt động thế nào? Invite có thời hạn không?**

---

## 4. Quản Lý Hóa Đơn & Chia Chi Phí

16. **Hệ thống hỗ trợ mấy loại chia chi phí (split type)? Mỗi loại khác nhau thế nào?**
    - Gợi ý: EQUAL (chia đều), PERCENTAGE (% mỗi người), CUSTOM (số tiền cố định), WEIGHT (tỷ lệ trọng số).

17. **Validation nào được thực hiện khi tạo invoice item với split type?**
    - Gợi ý: `validateItemSplits()` — PERCENTAGE phải tổng bằng 100%; CUSTOM phải tổng bằng `item.amount`; WEIGHT phải > 0.

18. **Multi-currency hoạt động thế nào khi group có `baseCurrency = VND` nhưng invoice đơn vị là `USD`?**
    - Gợi ý: gọi `exchangeRateService.getRate()` → lưu `convertedAmountTotal`, `exchangeRate`, `baseCurrency` vào invoice; OriginalDebt cũng lưu `exchangeRateUsed` và lock tỷ giá tại thời điểm tạo.

19. **Tại sao tỷ giá hối đoái được "lock" (khóa) vào thời điểm tạo invoice? Rủi ro nếu không lock?**
    - Gợi ý: tránh tổng nợ thay đổi khi tỷ giá biến động; nếu không lock, tổng debt sẽ không khớp với số tiền đã thực sự chia.

20. **OCR hóa đơn bằng Gemini Vision API hoạt động như thế nào? Kết quả không chính xác thì xử lý ra sao?**
    - Gợi ý: chụp ảnh → gửi lên API → parse JSON response; kết quả không chính xác → user chỉnh sửa thủ công.

21. **Invoice có thể được điều chỉnh (adjustment) sau khi phát hành không? Luồng điều chỉnh như thế nào?**
    - Gợi ý: `isAdjustment = true`, `originalInvoiceId` trỏ về invoice gốc; cần tạo payment request mới.

---

## 5. Thuật Toán Thanh Toán Nợ (Debt Settlement Engine)

22. **Hệ thống sử dụng thuật toán nào để tối ưu số lượng giao dịch khi thanh toán nợ?**
    - Gợi ý: Greedy (default) và MinCostFlow (khi phát hiện nợ chéo/mutual debts).

23. **Giải thích thuật toán Greedy Settlement. Khi nào nó cho kết quả tối ưu?**
    - Gợi ý: sort debtors và creditors giảm dần; ghép lớn nhất trước; tối ưu về số giao dịch khi không có nợ chéo.

24. **MinCostFlow Settlement khác Greedy như thế nào? Cho ví dụ cụ thể.**
    - Gợi ý: A nợ B 100k, B nợ A 60k → net-off → A chỉ cần trả B 40k (1 giao dịch thay vì 2).

25. **`hasMutualDebts()` hoạt động thế nào? Độ phức tạp thuật toán?**
    - Gợi ý: build Set các pair (debtor, creditor); check reverse pair → O(n) trong đó n = số raw debts.

26. **Debt Allocation (FIFO) là gì? Tại sao cần mapping giao dịch về các khoản nợ gốc?**
    - Gợi ý: `allocateDebtsForTransfer()` sort theo `createdAt ASC`; cần để tracking `remainingAmount` chính xác trên từng `OriginalDebt`; audit trail.

27. **Khi tính net balance, điều gì xảy ra nếu tổng nợ không khớp với tổng phân bổ?**
    - Gợi ý: `throw new Error('Cannot allocate...')` — được log lại, cần investigate data inconsistency.

---

## 6. Ví Điện Tử & Thanh Toán

28. **Người dùng có thể nạp tiền vào ví bằng cách nào? Luồng xử lý VNPay top-up như thế nào?**
    - Gợi ý: tạo `TopUp` (PENDING) → build VNPay URL với HMAC-SHA512 → redirect → IPN callback → verify signature → update balance.

29. **Idempotency trong xử lý VNPay callback được đảm bảo thế nào?**
    - Gợi ý: kiểm tra `vnpayTxnRef` đã tồn tại chưa trước khi process; tránh double-credit.

30. **Transfer (thanh toán nợ giữa thành viên) có OTP verification không? Tại sao?**
    - Gợi ý: có — `otp`, `otpExpiresAt`, `otpVerified` trên Transfer model; OTP gửi qua email; bảo vệ khỏi transfer trái phép.

31. **Withdrawal (rút tiền) có bao nhiêu bước? Tại sao cần OTP cho rút tiền?**
    - Gợi ý: PENDING → OTP_SENT → (user verify OTP) → PROCESSING → COMPLETED/REJECTED; bảo vệ tài sản.

32. **Transaction history lưu trữ những thông tin gì? `balanceBefore` và `balanceAfter` có ý nghĩa gì?**
    - Gợi ý: immutable audit trail; `referenceId`/`referenceType` link về nguồn gốc; không có `updatedAt`.

33. **Nếu hệ thống crash giữa chừng khi đang xử lý transfer (balance đã trừ nhưng chưa tạo transaction), xử lý thế nào?**
    - Gợi ý: thảo luận về MongoDB transactions (atomic operations), hoặc compensating transactions.

---

## 7. Subscription (Đăng Ký Định Kỳ)

34. **Subscription hoạt động như thế nào? Hệ thống tự động trừ tiền của thành viên khi nào?**
    - Gợi ý: scheduler chạy mỗi giờ; kiểm tra `nextBillingDate <= now`; tính `feePerMember = amount / activeMembers`; trừ balance từng member.

35. **Logic retry khi charge thất bại (không đủ số dư) là gì?**
    - Gợi ý: `retryCount`, `failureReason`, `lastAttemptAt`; trạng thái `PAST_DUE`; thông báo `SUBSCRIPTION_BILLING_FAILED`.

36. **Điều gì xảy ra với subscription khi group bị xóa?**
    - Gợi ý: `groupDeleted = true` → subscription bị cancel; không tiếp tục charge.

37. **`nextBillingDate` được tính thế nào cho chu kỳ MONTHLY? Xử lý trường hợp tháng 31 chuyển sang tháng 2?**
    - Gợi ý: `next.setMonth(next.getMonth() + 1)` — JavaScript tự handle overflow (e.g., 31/1 → 3/3); đây có thể là bug/edge case cần thảo luận.

---

## 8. Real-Time & Notifications

38. **Socket.IO được dùng để làm gì trong hệ thống? Authentication qua WebSocket hoạt động thế nào?**
    - Gợi ý: real-time chat trong group; notification push; JWT trong `handshake.auth.token`; auto-join `user:{userId}` room.

39. **Hệ thống có bao nhiêu loại notification? Push notification hoạt động thế nào trên mobile?**
    - Gợi ý: 13 NotificationType; Firebase FCM gửi qua `fcmToken` được lưu trên User; `pushNotificationsEnabled` flag.

40. **Email notification được gửi trong những trường hợp nào? Bảo mật SMTP credentials thế nào?**
    - Gợi ý: OTP verification, welcome email, transfer OTP, withdrawal OTP; credentials trong `.env`.

41. **Nếu FCM token của user đã expired/invalid khi gửi push notification, xử lý thế nào?**
    - Gợi ý: Firebase trả lỗi `messaging/registration-token-not-registered`; nên xóa `fcmToken` khỏi DB.

---

## 9. Caching & Performance

42. **Redis được sử dụng cho mục đích gì trong hệ thống?**
    - Gợi ý: (1) cache API responses (invoice list/detail, subscription), (2) rate limiting, (3) OTP storage, (4) exchange rate cache.

43. **Cache invalidation được thực hiện khi nào và như thế nào?**
    - Gợi ý: `deleteKeysByPrefix()` khi create/update/delete invoice trong group; TTL-based expiry (45-60 giây).

44. **Redis key naming convention là gì? Tại sao quan trọng?**
    - Gợi ý: `splitpal:cache:invoice:{groupId}:list:{userId}:{status}`; namespace isolation; dễ invalidate theo prefix.

45. **Điều gì xảy ra nếu Redis bị down? Hệ thống có hoạt động được không?**
    - Gợi ý: cache miss → query DB trực tiếp; rate limit fallback in-memory Map; graceful degradation.

46. **Exchange rate được cache trong bao lâu? Tại sao chọn 1 giờ?**
    - Gợi ý: Redis TTL = 3600s; balance giữa freshness và API rate limit (free tier); static fallback rates.

---

## 10. Kiến Trúc Phần Mềm & Clean Code

47. **Frontend Flutter được tổ chức theo pattern gì?**
    - Gợi ý: feature-first folder structure (`auth`, `groups`, `invoices`, etc.); mỗi feature có `data/domain/presentation`; Clean Architecture.

48. **Repository pattern được áp dụng như thế nào trên Flutter?**
    - Gợi ý: `domain/repositories` (abstract), `data/repositories` (concrete); Dependency Injection với `get_it`.

49. **State management trên Flutter sử dụng gì? Tại sao không dùng BLoC hay Riverpod?**
    - Gợi ý: `provider` package; đủ dùng cho scale hiện tại; so sánh ưu/nhược.

50. **Service layer trên backend tách biệt với controller layer như thế nào? Lợi ích?**
    - Gợi ý: controller chỉ parse request/response; service chứa business logic; dễ test, dễ maintain.

---

## 11. Database Design

51. **Tại sao dùng MongoDB thay vì PostgreSQL cho hệ thống này?**
    - Gợi ý: invoice items có structure linh hoạt (splits khác nhau cho từng item); schema ít join; horizontal scale. Nhược: không có foreign key constraints.

52. **Indexing strategy trong MongoDB của hệ thống như thế nào? Cho ví dụ.**
    - Gợi ý: compound index `{ userId: 1, createdAt: -1 }` cho Transaction; `{ groupId: 1, status: 1 }` cho Invoice; tại sao không index toàn bộ field?

53. **`OriginalDebt` model có vai trò gì? Tại sao cần lưu `remainingAmount` riêng?**
    - Gợi ý: track từng khoản nợ gốc từ invoice; `remainingAmount` giảm dần khi trả → biết chính xác còn nợ bao nhiêu mỗi invoice.

54. **Giải thích quan hệ giữa Invoice → InvoiceItem → OriginalDebt → Transfer → TransferDebtAllocation.**
    - Gợi ý: chuỗi từ "tạo chi phí" → "phân bổ nợ theo item" → "tổng hợp nợ theo cặp người dùng" → "tạo giao dịch thanh toán" → "link giao dịch về debt gốc".

55. **Tại sao `Transaction` không có `updatedAt` nhưng các model khác có?**
    - Gợi ý: Transaction là immutable audit log — không được sửa; `timestamps: { createdAt: true, updatedAt: false }`.

---

## 12. Testing & Deployment

56. **Hệ thống có test nào không? Loại test nào được ưu tiên?**
    - Gợi ý: `concurrency-smoke.ts` script; `mongodb-memory-server` trong dev dependencies; widget tests trong Flutter.

57. **Concurrency test (`concurrency-smoke.ts`) kiểm tra điều gì? Tại sao cần test concurrency?**
    - Gợi ý: kiểm tra race condition khi nhiều user đồng thời thanh toán — tránh double-spend, negative balance.

58. **Hệ thống được deploy như thế nào? `render.yaml` cấu hình gì?**
    - Gợi ý: Render.com; web service Node.js; các environment variables (MongoDB URI, Redis URL, JWT Secret, VNPay keys, Firebase).

59. **Các environment variables quan trọng nào cần được cấu hình cho production?**
    - Gợi ý: `JWT_SECRET`, `MONGODB_URI`, `REDIS_URL`, `VNPAY_TMN_CODE`, `VNPAY_HASH_SECRET`, `FIREBASE_SERVICE_ACCOUNT_JSON`, `SMTP_*`.

60. **Làm thế nào để scale hệ thống khi số lượng người dùng tăng lên?**
    - Gợi ý: horizontal scale Node.js với Redis session/rate-limit; MongoDB replica set; CDN cho file upload (hiện dùng local `uploads/`).

---

## 13. Xử Lý Lỗi & Edge Cases

61. **Điều gì xảy ra nếu tạo PaymentRequest nhưng không có thành viên nào có nợ?**

62. **Nếu một thành viên rời nhóm khi đang có nợ chưa thanh toán, luồng xử lý thế nào?**

63. **Khi PaymentRequest bị CANCEL, các Transfer liên quan xử lý thế nào? OriginalDebt có được hoàn lại không?**

64. **Người dùng có thể tạo invoice với amountTotal = 0 không? Validation ở đâu?**

65. **Giải thích cơ chế xử lý race condition khi 2 transfer cùng lúc deduct balance của cùng một user.**
    - Gợi ý: MongoDB atomic `findOneAndUpdate` với `$inc`; optimistic locking vs pessimistic locking.

---

## 14. Câu Hỏi Về Quyết Định Thiết Kế

66. **Tại sao chọn Socket.IO thay vì thuần WebSocket hay Server-Sent Events cho real-time features?**
    - Gợi ý: fallback polling, room management, middleware authentication tích hợp sẵn.

67. **Tại sao OTP email được lưu trong Redis thay vì MongoDB?**
    - Gợi ý: TTL tự động, read/write nhanh, không cần persistence dài hạn.

68. **Hệ thống có hỗ trợ offline mode không? Nếu không, tại sao?**
    - Gợi ý: cần real-time balance sync, tránh conflict; offline mode phức tạp về conflict resolution.

69. **Tại sao không dùng Stripe/MoMo thay vì VNPay?**
    - Gợi ý: VNPay phổ biến ở Việt Nam, hỗ trợ thẻ nội địa, chi phí tích hợp; target market là người Việt.

70. **Nếu phải làm lại hệ thống, bạn sẽ thay đổi điều gì?**
    - Gợi ý: refresh token, message queue (Bull/BullMQ) thay vì scheduler đơn giản, GraphQL subscription, unit test đầy đủ hơn.

---

## 15. Câu Hỏi Nâng Cao (Giảng Viên Có Thể Hỏi Thêm)

71. **HMAC-SHA512 được dùng ở đâu? Giải thích cơ chế ký (sign) và xác minh (verify) trong VNPay.**
    - Gợi ý: `buildSignData()` sort params → join thành string → HMAC-SHA512 với `VNPAY_HASH_SECRET` → hex uppercase.

72. **Thuật toán MinCostFlow trong tài chính thực tế có tên gọi nào khác?**
    - Gợi ý: "Debt simplification", "Bill Splitting Optimization" — bài toán tương tự bài toán luồng cực đại (max-flow/min-cost).

73. **TOTP (Time-based OTP) hoạt động dựa trên nguyên lý gì? Tại sao cần `window: 2`?**
    - Gợi ý: HOTP + time step 30s; HMAC-SHA1; `window: 2` cho phép lệch ±60 giây giữa server và device.

74. **Giải thích sự khác biệt giữa `bcrypt.hash()` cho mật khẩu và cho backup codes. Có gì đáng chú ý?**
    - Gợi ý: salt rounds 10; backup code ngắn (8 hex chars) → rainbow table risk thấp hơn password; có thể dùng `argon2` thay thế.

75. **Chuẩn hóa tiếng Việt trong VNPay `orderInfo` (`normalizeOrderInfo()`) xử lý vấn đề gì?**
    - Gợi ý: remove diacritics (NFD + strip combining marks), thay ký tự đặc biệt bằng space; VNPay chỉ chấp nhận ASCII.
