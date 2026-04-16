import dotenv from 'dotenv';
import path from 'path';

const envPath = path.resolve(__dirname, '../.env');
dotenv.config({ path: envPath });

import { AIService } from '../src/service/aiService';

async function run() {
    const text = "Hôm qua đi nhậu hết 1 củ 2. Nam 500k, Linh 300k, anh Hùng lo phần còn lại.";
    console.log("Input:", text);
    try {
        const result = await AIService.extractInvoiceData(text);
        console.log(JSON.stringify(result, null, 2));
    } catch (e) {
        console.error(e);
    }
}
run();
