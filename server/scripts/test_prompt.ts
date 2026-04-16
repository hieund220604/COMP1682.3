import dotenv from 'dotenv';
import path from 'path';

// Construct the absolute path to the .env file in the server root
const envPath = path.resolve(__dirname, '../.env');
dotenv.config({ path: envPath });

import { AIService } from '../src/service/aiService';

const testCases = [
    {
        name: "1. Số lượng và đơn giá cơ bản",
        text: "Nay ăn lẩu 4 người 200k/người nhé. Nhớ ck tôi nha"
    },
    {
        name: "2. Phép nhân số lượng và ngôn từ chia đều",
        text: "3 × bánh mì 25k, nước 40k. Bọn tao 3 đứa chia đều tổng bill nhé."
    },
    {
        name: "3. Tiếng lóng tiền tệ (củ), nhắc đích danh",
        text: "Hôm qua đi nhậu hết 1 củ 2. Nam 500k, Linh 300k, anh Hùng lo phần còn lại."
    },
    {
        name: "4. Đại từ nhân xưng và món dùng chung",
        text: "Lan uống trà sữa 50k, Vy hồng trà 40k. Mình trả tiền ship chung 20k nhé."
    },
    {
        name: "5. Chia tỷ lệ (shares)",
        text: "Tối qua ăn bò né tổng thiệt hại 300k. Chia theo tỷ lệ 2:1 cho Linh và Nam nhé, vì Nam ăn gấp đôi."
    },
    {
        name: "6. Nhiều món khác giá, loại trừ người",
        text: "Combo gà + pepsi 79k, thêm 2 phần khoai tây mỗi phần 20k. Mọi người trừ Bảo chia đều nhé, Bảo được miễn phí."
    },
    {
        name: "7. Không có tổng tiền, giá xấp xỉ",
        text: "Bạc xỉu khoảng 35k, cafe đen 25k. Ai cũng như nhau, tự chia nha."
    },
    {
        name: "8. Nhiễu từ khóa, Emoji, Hashtag",
        text: "🍜 phở của @Tuấn 50k, 🥤 rau má của mình 20k. Tổng cộng 70k nghen."
    },
    {
        name: "9. Disclaimer tổng tiền và tiền đính kèm",
        text: "Tiêu hết 800k rồi, tất cả là 800k đó đã bao gồm VAT. Anh em mỗi đứa gửi tôi 200k lẹ lên."
    },
    {
        name: "10. Không phải hóa đơn (Non-bill gating)",
        text: "Hôm nay đi ăn tiệc vui quá chừng! Lần sau mọi người nhớ đi động đủ nha 😍"
    }
];

async function runTests() {
    console.log("🚀 Bắt đầu test AI Prompt Extraction mới...\n");

    if (!process.env.GEMINI_API_KEY) {
        console.error("❌ LỖI: Không tìm thấy GEMINI_API_KEY trong file .env!");
        process.exit(1);
    }

    for (let i = 0; i < testCases.length; i++) {
        const tc = testCases[i];
        console.log(`\n======================================================`);
        console.log(`[TEST CASE ${i + 1}] ${tc.name}`);
        console.log(`💬 Input: "${tc.text}"`);
        console.log(`------------------------------------------------------`);
        
        try {
            const result = await AIService.extractInvoiceData(tc.text);
            
            const summary = {
                items: result.items.map((i: any) => ({
                    name: i.name,
                    qty: i.quantity,
                    price: i.unitPrice,
                    amount: i.amount,
                    assignees: i.assignees,
                    shared: i.shared
                })),
                amountTotal: result.amountTotal,
                splitMethod: result.splitMethod,
                splitDetails: result.splitDetails,
                reviewNotes: result.reviewNotes,
                confidence: result.confidence
            };
            
            console.log(JSON.stringify(summary, null, 2));

        } catch (error) {
            console.error(`Error in test case ${i + 1}:`, error);
        }
    }
    
    console.log(`\n🎉 Hoàn thành test!`);
    process.exit(0);
}

runTests();
