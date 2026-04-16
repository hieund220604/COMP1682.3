import { GoogleGenerativeAI } from '@google/generative-ai';
import { Group } from '../models/Group';

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const genAI = GEMINI_API_KEY ? new GoogleGenerativeAI(GEMINI_API_KEY) : null;

const DEFAULT_SPLIT_DETAILS = {
    perPersonAmount: 0,
    percentages: [],
    shares: [],
    customAmounts: []
};

const buildExtractionPrompt = (groupCurrency: string, todayDate: string) => `You are an expert text-to-bill parser. Analyze the user's message text and extract ALL bill information in structured JSON format.

The input is plain text, not an image.
The text may be informal, short, missing punctuation, mixed Vietnamese and English, or written like chat messages.

CONTEXT (provided by system, do not infer):
- invoiceDate: \${todayDate}
- groupCurrency: \${groupCurrency}

IMPORTANT: Return ONLY valid JSON (no markdown, no extra text). The JSON must follow this exact structure:
{
  "title": "short bill title",
  "invoiceDate": "YYYY-MM-DD",
  "items": [
     {
        "name": "item name",
        "quantity": number,
        "unitPrice": number,
        "amount": number,
        "assignees": ["person name"],
        "shared": true
     }
  ],
  "amountTotal": number,
  "currency": "VND/USD/EUR/...",
  "note": "original or normalized message text (optional)",
  "confidence": "HIGH/MEDIUM/LOW",
  "splitMethod": "equal/percentage/custom_amount/shares/unknown",
  "splitDetails": {
     "perPersonAmount": number,
     "percentages": [
        {
          "name": "person name",
          "percentage": number
        }
     ],
     "shares": [
        {
          "name": "person name",
          "share": number
        }
     ],
     "customAmounts": [
        {
          "name": "person name",
          "amount": number
        }
     ]
  },
  "reviewNotes": ["short note about ambiguity or assumptions"]
}

Core rules:
1. The input is MESSAGE TEXT only. Do not look for OCR layout or receipt structure.
2. Extract all distinct bill items mentioned in the text.
3. amountTotal must be the best total inferred from the text.
4. currency MUST equal groupCurrency from CONTEXT (do not override based on text).
5. invoiceDate MUST equal invoiceDate from CONTEXT (do not infer from text).
6. quantity defaults to 1 if not specified.
7. unitPrice: calculate if only total line amount is known.
8. Return ONLY the JSON object, nothing else.
9. Do NOT include markdown formatting.
10. Always return numbers as numeric values, not strings.
11. Do NOT invent people, items, prices, or totals that are not supported by the text.
12. If something is unclear, keep the safest extraction and explain briefly in reviewNotes.
13. Do NOT translate. Keep item names in the original language from the message.
14. Non-bill gating: If the message contains NO monetary values or payment intent, IMMEDIATELY return empty items, amountTotal = 0, confidence = LOW, and explain it's not a bill in reviewNotes.

Money normalization rules:
1. Normalize common Vietnamese money formats:
    - 50k / 50 K / 50k đ / 50 k = 50000
    - 50 nghìn / 50 ngàn = 50000
    - 50.000 / 50,000 / 50000đ = 50000
    - 1tr / 1 triệu = 1000000
    - 1tr2 = 1200000
    - 1tr5 / 1.5tr = 1500000
    - nửa triệu = 500000
2. Extended Vietnamese currency slang:
    - 1 củ / 1 lít / 1 chai = 1000000
    - 2 củ = 2000000
    - rưỡi suffix: "1 triệu rưỡi" = 1500000; "50 ngàn rưỡi" = 50500
    - chục: "một chục" = 10000
3. Normalize casual expressions when safe:
    - "80 nhé" may mean 80000 if surrounding prices are in k-format

Message format & noise filtering rules:
1. Emoji: strip from item name before parsing (e.g., "🍜 phở 50k" → item name = "phở").
2. Approximate qualifiers ("khoảng", "tầm", "chừng", "~"): extract value, add "approximate" to reviewNotes.

Item extraction rules:
1. If multiple items have separate prices, split them into separate items.
2. DO NOT put the entire input text as an item name. Example: "Hôm qua đi nhậu hết 1 củ 2" -> The item is "Nhậu", not the whole sentence.
3. If no specific items are mentioned (only a shared event like "nhậu", "tiệc", "trà sữa"), create exactly ONE item with the event name and the total amount.
4. "200k/người, 4 người" → quantity = 4, unitPrice = 200000, amount = 800000.
5. "3 × 30k" or "3 * 30k" → quantity = 3, unitPrice = 30000, amount = 90000.

Assignee rules:
1. Titles before names: "anh X", "chị X", "em X", "bạn X" → assignee = "X" or keep full form
2. First-person ("tôi", "mình", "tao", "tau") → assign to "Người gửi"
3. Exclusion ("mọi người trừ Nam") → set splitMethod = "equal", note "excludes Nam" in reviewNotes
4. Shared/common ("ăn chung", "cả bàn", "ship", "VAT") => shared = true.

ADVANCED SPLIT METHOD AND ASSIGNMENT LOGIC (CRITICAL):
You must deduce "splitMethod" and build "splitDetails" systematically.
1. Return EXACTLY ONE of: "equal", "percentage", "custom_amount", "shares", "unknown".
2. "equal": Use when the text says "chia đều", "ai cũng như nhau", "mỗi người ...", "cứ chia đôi/ba/N". Set splitDetails.perPersonAmount.
3. "shares": Use when the text says "tỷ lệ X:Y", "chia 2:1", "ăn gấp đôi". Set splitDetails.shares = [{"name":"A", "share":2}, ...].
4. "custom_amount": Use when the text explicitly maps specific people to specific money amounts.
   - Example 1: "Nam 50k, Linh 30k" => customAmounts = [{"name":"Nam", "amount":50000}, {"name":"Linh", "amount":30000}].
   - Example 2 (The Remainder Logic): "Nam 500k, Linh 300k, anh Hùng lo phần còn lại", Total = 1200000.
     * Step 1: Identify custom amounts (Nam 500k, Linh 300k). Total specific = 800000.
     * Step 2: DEDUCE the remainder for Hùng: 1200000 - 800000 = 400000.
     * Step 3: customAmounts = [{"name":"Nam", "amount":500000}, {"name":"Linh", "amount":300000}, {"name":"Hùng", "amount":400000}].
   - "miễn phí cho Nam" -> custom_amount (amount = 0).

Output quality rules:
1. title: prefer a short meaningful summary ("Ăn phở", "Nhậu", "Chi tiêu nhóm")
2. reviewNotes: briefly mention any remainder calculation or inference used.
3. If explicit total exists and |total - sum(items)| / max(total, 1) > 0.05, add a reviewNotes entry.

Return valid JSON ONLY.

Chat message: `;

const OCR_PROMPT = `You are an expert invoice OCR system. Analyze this invoice image and extract ALL information in structured JSON format.

IMPORTANT: Return ONLY valid JSON (no markdown, no extra text). The JSON must follow this exact structure:
{
  "title": "vendor/shop name",
  "invoiceDate": "YYYY-MM-DD",
  "items": [
    {
      "name": "item name",
      "quantity": number,
      "unitPrice": number,
      "amount": number
    }
  ],
  "amountTotal": number,
  "currency": "VND/USD/EUR/...",
  "note": "any additional notes (optional)",
  "confidence": "HIGH/MEDIUM/LOW"
}

Rules:
1. Extract ALL line items from invoice
2. amountTotal must be the final total
3. Currency should be detected (VND for Vietnam, USD for US, etc.)
4. If date is unclear, use today's date in YYYY-MM-DD format
5. quantity: default to 1 if not specified
6. unitPrice: calculate if only amount is shown (amount/quantity)
7. confidence: HIGH if all data clear, MEDIUM if some unclear, LOW if mostly estimate
8. Return ONLY the JSON object, nothing else
9. Do NOT include markdown formatting or code fences

Return valid JSON ONLY.`;

const DEBT_STYLE_LABELS: Record<string, string> = {
    funny: 'Funny and cheerful',
    polite: 'Polite and respectful',
    serious: 'Serious and decisive',
    poetic: 'Poetic and dreamy',
    gangster: 'Gangster and fun'
};

const DEBT_STYLE_INSTRUCTIONS: Record<string, string> = {
    funny: 'Write in a FUNNY style using Gen Z slang, memes, and hilarious comparisons. Example: share the pain of an empty wallet, joke about selling a kidney. The tone should make the reader laugh.',
    polite: 'Write in a POLITE style, gentle and respectful. Use honorifics and tactful wording. Remind in a subtle way without pressure. Sound like a good friend gently reminding you.',
    serious: 'Write in a SERIOUS style, direct and decisive. Get straight to the point, clearly state the amount and deadline. Professional tone, no jokes, convey urgency.',
    poetic: 'Write in a POETIC style, dreamy and imaginative. Use rhyme, metaphor, and romantic imagery. Can be written as traditional verse or free poetry. Tone should be emotional and artistic.',
    gangster: 'Write in a FUN GANGSTER style using street slang and threatening tone but HUMOROUS (not genuinely threatening). Example: mention "brothers," "code of honor," "settle it properly." Tone should be playful and entertaining, not violent.'
};

const DEBT_STYLE_FALLBACKS: Record<string, string[]> = {
    funny: [
        'Hey {name}! Dude, where\'s my money?? {amount} {currency}, did you forget? My wallet is starving! Transfer it quick before I have to eat instant noodles!',
        'Hey {name}! {amount} {currency}, remember that? You\'re so forgetful, but I remember like my crush remembers their ex! Come on, pay up!',
        '{name}! So you owe me {amount} {currency} and you\'re ghosting me? I thought you vanished! Transfer it so we can stay friends!'
    ],
    polite: [
        'Hi {name}! I wanted to gently remind you about the {amount} {currency} you owe me. Whenever you have a chance, please settle it for me. Thank you so much!',
        'Hi {name}! If you don\'t mind, I wanted to remind you about {amount} {currency}. I understand everyone\'s busy, but could you find time to transfer it? Thank you!',
        '{name}, I wanted to gently remind you about {amount} {currency}. No rush at all, whenever it\'s convenient, just transfer it to me. Wishing you a great day!'
    ],
    serious: [
        '{name}, I need to remind you about the {amount} {currency} debt. I suggest you settle this soon. Delays affect our finances. Please handle this today.',
        'Notice to {name}: The {amount} {currency} debt has not been settled yet. Please transfer immediately. This is an official reminder.',
        '{name}, the {amount} {currency} is now overdue. I strongly suggest you prioritize payment right now. If there\'s any difficulty, let\'s discuss it directly.'
    ],
    poetic: [
        'Dear {name},\nMoney flows like autumn leaves,\n{amount} {currency} awaits promises to be kept.\nPlease remember the way back,\nSettle the promise you once made.',
        '{name}, dear one,\nLike the moon remembers the sea,\nI remember {amount} {currency} you owe me.\nPlease don\'t let the distance grow,\nTransfer it so our bond stays complete.',
        'Dear {name},\nThe autumn wind carries a message,\n{amount} {currency} waits like petals of a flower.\nI hope you\'ll open your wallet and give,\nSo our friendship grows eternal with love.'
    ],
    gangster: [
        'Yo {name}! Listen here, {amount} {currency} we talked about, and I still don\'t see it! That\'s not how we roll! Handle it properly!',
        '{name}! This is my last reminder, {amount} {currency}, bring it to the table! Everyone knows you don\'t owe people and disappear! Transfer it before I get upset!',
        'Listen {name}! {amount} {currency}, we settled it fair and square! Honor means everything, debts must be paid! Get it done or we\'ll have a problem!'
    ]
};

export class AIService {
    static async extractInvoiceData(text: string, groupId?: string): Promise<any> {
        const todayDate = new Date().toISOString().slice(0, 10);
        let groupCurrency = 'VND';
        if (groupId) {
            try {
                const group = await Group.findById(groupId).select('baseCurrency');
                if (group?.baseCurrency) groupCurrency = group.baseCurrency;
            } catch (error: any) {
                console.warn('[AI] Failed to load group currency, defaulting to VND:', error.message);
            }
        }

        // Try Gemini API first
        if (genAI) {
            try {
                const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
                const prompt = buildExtractionPrompt(groupCurrency, todayDate) + text;
                const result = await model.generateContent(prompt);
                const responseText = result.response.text();

                if (responseText) {
                    const cleaned = this.cleanJsonResponse(responseText);
                    const parsed = JSON.parse(cleaned.trim());
                    const amountTotal = typeof parsed.amountTotal === 'number' && Number.isFinite(parsed.amountTotal)
                        ? parsed.amountTotal
                        : (typeof parsed.amount === 'number' && Number.isFinite(parsed.amount)
                            ? parsed.amount
                            : undefined);
                    const reviewNotes = Array.isArray(parsed.reviewNotes)
                        ? parsed.reviewNotes
                        : (typeof parsed.reviewNote === 'string' && parsed.reviewNote.trim().length > 0
                            ? [parsed.reviewNote]
                            : []);
                    const splitDetails = parsed.splitDetails && typeof parsed.splitDetails === 'object'
                        ? parsed.splitDetails
                        : DEFAULT_SPLIT_DETAILS;

                    const data = {
                        groupId,
                        title: parsed.title || text.slice(0, 60),
                        amount: amountTotal,
                        amountTotal: amountTotal,
                        currency: groupCurrency,
                        date: todayDate,
                        invoiceDate: todayDate,
                        note: parsed.note || text,
                        items: Array.isArray(parsed.items) ? parsed.items : [],
                        splitMethod: typeof parsed.splitMethod === 'string' ? parsed.splitMethod : 'unknown',
                        splitDetails,
                        confidence: typeof parsed.confidence === 'string' ? parsed.confidence : 'LOW',
                        reviewNotes,
                        extractedBy: 'gemini'
                    };

                    console.log('[AI] Gemini extraction successful:', JSON.stringify(data));
                    return data;
                }
            } catch (error: any) {
                console.error('[AI] Gemini extraction failed, falling back to regex:', error.message);
                // Fall through to regex fallback
            }
        } else {
            console.warn('[AI] GEMINI_API_KEY not configured, using regex fallback');
        }

        // Regex fallback
        const data = this.regexFallback(text, groupId, groupCurrency, todayDate);
        console.log('[AI] Regex fallback extraction:', JSON.stringify(data));
        return data;
    }

    static async extractInvoiceFromImage(
        imageBuffer: Buffer,
        mimeType: string
    ): Promise<any> {
        const todayDate = new Date().toISOString().slice(0, 10);
        if (!genAI) {
            return {
                title: '',
                invoiceDate: todayDate,
                items: [],
                amountTotal: 0,
                currency: 'VND',
                note: null,
                confidence: 'LOW',
                extractionError: 'Gemini API is not configured'
            };
        }

        const MAX_RETRIES = 3;
        const BASE_DELAY_MS = 1500;

        for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
            try {
                console.log(`[AI] OCR attempt ${attempt}/${MAX_RETRIES}, mimeType=${mimeType}, size=${imageBuffer.length} bytes`);
                const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
                const imagePart = {
                    inlineData: {
                        data: imageBuffer.toString('base64'),
                        mimeType
                    }
                };
                const result = await model.generateContent([OCR_PROMPT, imagePart]);
                const responseText = result.response.text() || '';

                if (!responseText) {
                    console.warn(`[AI] OCR attempt ${attempt}: empty response from Gemini`);
                    if (attempt < MAX_RETRIES) {
                        await this.delay(BASE_DELAY_MS * attempt);
                        continue;
                    }
                    return {
                        title: '',
                        invoiceDate: todayDate,
                        items: [],
                        amountTotal: 0,
                        currency: 'VND',
                        note: null,
                        confidence: 'LOW',
                        extractionError: 'No response from Gemini API'
                    };
                }

                const cleaned = this.cleanJsonResponse(responseText);
                const parsed = JSON.parse(cleaned.trim());
                const amountTotal = this.parseNumber(parsed.amountTotal ?? parsed.totalAmount ?? parsed.total) ?? 0;
                const invoiceDate = typeof parsed.invoiceDate === 'string' && parsed.invoiceDate.trim().length > 0
                    ? parsed.invoiceDate.trim()
                    : todayDate;
                const currency = typeof parsed.currency === 'string' && parsed.currency.trim().length > 0
                    ? parsed.currency.trim().toUpperCase()
                    : 'VND';
                const confidence = typeof parsed.confidence === 'string' && parsed.confidence.trim().length > 0
                    ? parsed.confidence.trim().toUpperCase()
                    : 'LOW';

                console.log(`[AI] OCR attempt ${attempt} succeeded: amountTotal=${amountTotal}, confidence=${confidence}`);
                return {
                    title: typeof parsed.title === 'string' && parsed.title.trim().length > 0
                        ? parsed.title.trim()
                        : 'Scanned Invoice',
                    invoiceDate,
                    items: Array.isArray(parsed.items) ? parsed.items : [],
                    amountTotal,
                    currency,
                    note: typeof parsed.note === 'string' ? parsed.note : null,
                    confidence,
                    extractionError: null
                };
            } catch (error: any) {
                const isRateLimit = error?.status === 429 || error?.message?.includes('429') || error?.message?.includes('quota') || error?.message?.includes('rate');
                console.error(`[AI] OCR attempt ${attempt} failed (isRateLimit=${isRateLimit}):`, error?.message || String(error));

                if (attempt < MAX_RETRIES) {
                    const delayMs = isRateLimit
                        ? BASE_DELAY_MS * Math.pow(2, attempt)  // 3s, 6s for rate limits
                        : BASE_DELAY_MS * attempt;               // 1.5s, 3s for other errors
                    console.log(`[AI] Retrying OCR in ${delayMs}ms...`);
                    await this.delay(delayMs);
                    continue;
                }

                return {
                    title: '',
                    invoiceDate: todayDate,
                    items: [],
                    amountTotal: 0,
                    currency: 'VND',
                    note: null,
                    confidence: 'LOW',
                    extractionError: `OCR Error: ${error.message || String(error)}`
                };
            }
        }

        // Should never reach here
        return {
            title: '',
            invoiceDate: todayDate,
            items: [],
            amountTotal: 0,
            currency: 'VND',
            note: null,
            confidence: 'LOW',
            extractionError: 'OCR failed after max retries'
        };
    }

    static async generateDebtReminder(params: {
        debtorName: string;
        debts: Array<{ amount?: number; currency?: string; reason?: string }>;
        style: string;
    }): Promise<string> {
        const debtorName = params.debtorName;
        const debts = Array.isArray(params.debts) ? params.debts : [];
        const styleKey = DEBT_STYLE_INSTRUCTIONS[params.style] ? params.style : 'funny';
        const totalAmount = debts.reduce((sum, d) => sum + (typeof d.amount === 'number' ? d.amount : 0), 0);
        const currency = debts.length > 0 && typeof debts[0].currency === 'string'
            ? debts[0].currency
            : 'VND';
        const styleLabel = DEBT_STYLE_LABELS[styleKey] || DEBT_STYLE_LABELS.funny;
        const styleInstruction = DEBT_STYLE_INSTRUCTIONS[styleKey] || DEBT_STYLE_INSTRUCTIONS.funny;
        const debtDetails = debts
            .map((d) => `- ${d.amount ?? 0} ${d.currency ?? currency} (Item: ${d.reason ?? 'Unknown'})`)
            .join('\n');
        const randomSeed = Math.floor(Math.random() * 100000);

        const prompt = `You are a debt reminder message writer for a group expense-sharing app.

TASK: Write ONE message to remind "${debtorName}" to pay their debt.

DEBT INFORMATION:
- Total owed: ${totalAmount} ${currency}
- Details:
${debtDetails}

REQUIRED STYLE: ${styleLabel}
${styleInstruction}

RULES:
1. Write in English
2. Do not use emojis
3. Mention the name "${debtorName}" and amount ${totalAmount} ${currency}
4. Length: 2-4 sentences, max 150 words
5. ONLY return the message content, NO explanations
6. Do NOT use quotation marks around the message
7. Make the style CLEARLY different according to requirements above
8. Be creative and COMPLETELY different from previous attempts (seed: ${randomSeed})`;

        if (genAI) {
            try {
                const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });
                const result = await model.generateContent(prompt);
                const text = result.response.text()?.trim() || '';
                if (text.length > 0) return text;
            } catch (error: any) {
                console.error('[AI] Debt reminder generation failed:', error.message);
            }
        } else {
            console.warn('[AI] GEMINI_API_KEY not configured, using fallback reminder');
        }

        return this.getDebtReminderFallback(debtorName, totalAmount, currency, styleKey);
    }

    private static regexFallback(
        text: string,
        groupId?: string,
        groupCurrency: string = 'VND',
        todayDate?: string
    ) {
        const fallbackDate = todayDate || new Date().toISOString().slice(0, 10);
        const amounts: number[] = [];
        let match;
        const regex = /(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d+)?|\d+(?:[.,]\d+)?)\s*(k|K|tr|m|M|nghìn|ngàn|triệu|củ|chai|lít)?/g;
        while ((match = regex.exec(text)) !== null) {
            let raw = match[1].replace(/,/g, '').replace(/\./g, '.');
            let numVal = Number(raw);
            const suffix = (match[2] || '').toLowerCase();
            if (suffix === 'k' || suffix === 'nghìn' || suffix === 'ngàn') numVal *= 1000;
            else if (suffix === 'tr' || suffix === 'm' || suffix === 'triệu' || suffix === 'củ' || suffix === 'chai' || suffix === 'lít') numVal *= 1000000;
            if (Number.isFinite(numVal) && numVal > 0) amounts.push(numVal);
        }

        const totalAmount = amounts.length > 0 ? amounts.reduce((a, b) => a + b, 0) : undefined;

        const title = text.length > 60 ? text.slice(0, 60) : text;

        return {
            groupId,
            title,
            amount: Number.isFinite(totalAmount) ? totalAmount : undefined,
            amountTotal: Number.isFinite(totalAmount) ? totalAmount : undefined,
            currency: groupCurrency,
            date: fallbackDate,
            invoiceDate: fallbackDate,
            note: text,
            items: [],
            splitMethod: 'unknown',
            splitDetails: DEFAULT_SPLIT_DETAILS,
            confidence: 'LOW',
            reviewNotes: [],
            extractedBy: 'regex'
        };
    }

    private static delay(ms: number): Promise<void> {
        return new Promise(resolve => setTimeout(resolve, ms));
    }

    private static cleanJsonResponse(responseText: string) {
        let cleaned = responseText.replace(/```json/gi, '').replace(/```/g, '');
        const jsonStart = cleaned.indexOf('{');
        const jsonEnd = cleaned.lastIndexOf('}');
        if (jsonStart !== -1 && jsonEnd !== -1 && jsonStart < jsonEnd) {
            cleaned = cleaned.substring(jsonStart, jsonEnd + 1);
        }
        return cleaned.trim();
    }

    private static parseNumber(value: any): number | undefined {
        if (typeof value === 'number' && Number.isFinite(value)) return value;
        if (typeof value === 'string') {
            const parsed = Number(value.replace(/[^0-9.-]/g, ''));
            return Number.isFinite(parsed) ? parsed : undefined;
        }
        return undefined;
    }

    private static getDebtReminderFallback(
        debtorName: string,
        amount: number,
        currency: string,
        style: string
    ) {
        const pool = DEBT_STYLE_FALLBACKS[style] || DEBT_STYLE_FALLBACKS.funny;
        const template = pool[Math.floor(Math.random() * pool.length)];
        return template
            .replace('{name}', debtorName)
            .replace('{amount}', amount.toFixed(0))
            .replace('{currency}', currency);
    }
}
