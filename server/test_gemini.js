// Quick test of Gemini API connectivity
require('dotenv').config();
const { GoogleGenerativeAI } = require('@google/generative-ai');

const apiKey = process.env.GEMINI_API_KEY;
if (!apiKey) {
    console.log('ERROR: No GEMINI_API_KEY found in .env');
    process.exit(1);
}
console.log('API Key found:', apiKey.substring(0, 10) + '...');

const genAI = new GoogleGenerativeAI(apiKey);
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

const prompt = `You are an expense extraction assistant. Given a chat message, extract expense info as JSON.
Return ONLY valid JSON: {"title":"...", "amount": number, "currency":"VND", "note":"..."}
Chat message: hom nay an pho 50k va tra sua 30k`;

async function test() {
    try {
        console.log('Calling Gemini API...');
        const result = await model.generateContent(prompt);
        const text = result.response.text();
        console.log('Raw response:', text);
        
        // Try parse JSON
        let cleaned = text.replace(/```json/g, '').replace(/```/g, '');
        const jsonStart = cleaned.indexOf('{');
        const jsonEnd = cleaned.lastIndexOf('}');
        if (jsonStart !== -1 && jsonEnd !== -1) {
            cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
        }
        const parsed = JSON.parse(cleaned.trim());
        console.log('\nParsed data:');
        console.log('  Title:', parsed.title);
        console.log('  Amount:', parsed.amount);
        console.log('  Currency:', parsed.currency);
        console.log('  Note:', parsed.note);
        console.log('\nSUCCESS: Gemini API is working!');
    } catch (error) {
        console.error('ERROR:', error.message);
    }
}

test();
