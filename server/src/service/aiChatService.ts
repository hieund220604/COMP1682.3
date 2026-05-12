import { GoogleGenerativeAI, FunctionDeclaration, SchemaType, Content, Part } from '@google/generative-ai';
import { AiChatSession } from '../models/AiChatSession';
import { AiChatMessage } from '../models/AiChatMessage';
import { Transaction } from '../models/Transaction';
import { SavingsGoal } from '../models/SavingsGoal';
import { OriginalDebt } from '../models/OriginalDebt';
import { User } from '../models/User';
import mongoose from 'mongoose';

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const genAI = GEMINI_API_KEY ? new GoogleGenerativeAI(GEMINI_API_KEY) : null;

const SYSTEM_INSTRUCTION = `You are an expert AI personal financial advisor integrated into the SplitPal application. 
Your ONLY purpose is to help the user manage their personal finances, analyze their spending, savings, debts, and provide financial advice based on their actual data.

RULES:
1. STRICT DOMAIN RESTRICTION: You must ONLY answer questions related to personal finance, budgeting, saving, debts, and the user's data within SplitPal. If the user asks about ANY other topic (e.g., coding, history, general chit-chat not related to finance), politely refuse and remind them of your purpose.
2. USE TOOLS: Always use the provided tools to fetch real data when the user asks about their balance, spending, savings, or debts. Do NOT guess or make up numbers.
3. BE CONCISE AND HELPFUL: Provide clear, actionable advice. If summarizing data, use bullet points for readability.
4. TONE: Professional, encouraging, and empathetic.
5. LANGUAGE: Always respond in English.`;

const getFinancialSummaryDeclaration: FunctionDeclaration = {
    name: 'get_financial_summary',
    description: 'Get the user\'s high-level financial summary including current balance, total savings, total debt, and expenses for the current month.',
};

const getRecentTransactionsDeclaration: FunctionDeclaration = {
    name: 'get_recent_transactions',
    description: 'Get the user\'s most recent transactions.',
    parameters: {
        type: SchemaType.OBJECT,
        properties: {
            limit: {
                type: SchemaType.INTEGER,
                description: 'Number of transactions to return (default 5, max 20)',
            },
        },
    },
};

const getSavingsGoalsDeclaration: FunctionDeclaration = {
    name: 'get_savings_goals',
    description: 'Get the user\'s active savings goals and their progress.',
};

const getDebtsDeclaration: FunctionDeclaration = {
    name: 'get_debts',
    description: 'Get a summary of the user\'s outstanding debts (both what they owe to others and what others owe them).',
};

const tools = [
    {
        functionDeclarations: [
            getFinancialSummaryDeclaration,
            getRecentTransactionsDeclaration,
            getSavingsGoalsDeclaration,
            getDebtsDeclaration,
        ],
    },
];

export class AiChatService {
    static async sendMessage(userId: string, message: string, sessionId?: string): Promise<{ reply: string, sessionId: string }> {
        if (!genAI) {
            throw new Error('Gemini API is not configured.');
        }

        let session;
        if (sessionId) {
            session = await AiChatSession.findOne({ _id: sessionId, userId });
            if (!session) throw new Error('Session not found');
        } else {
            const title = message.length > 30 ? message.substring(0, 30) + '...' : message;
            session = await AiChatSession.create({ userId, title });
        }

        // Save User Message
        await AiChatMessage.create({
            sessionId: session._id,
            role: 'user',
            content: message
        });

        // Fetch History
        const messages = await AiChatMessage.find({ sessionId: session._id }).sort({ createdAt: 1 });
        const history: Content[] = messages.map(msg => {
            if (msg.role === 'user') {
                return { role: 'user', parts: [{ text: msg.content }] };
            } else if (msg.role === 'model') {
                return { role: 'model', parts: [{ text: msg.content }] };
            } else if (msg.role === 'function') {
                return {
                    role: 'function',
                    parts: [{
                        functionResponse: {
                            name: msg.functionCallName || 'unknown',
                            response: JSON.parse(msg.content)
                        }
                    }]
                };
            }
            return { role: 'user', parts: [{ text: '' }] }; // fallback
        }).filter(h => h.parts[0]); // Ensure parts are valid

        const model = genAI.getGenerativeModel({
            model: 'gemini-2.5-flash',
            systemInstruction: SYSTEM_INSTRUCTION,
            tools: tools
        });

        const chat = model.startChat({ history: history.slice(0, -1) }); // Pass all but the latest message to history
        
        try {
            let result = await chat.sendMessage(message);
            let responseText = result.response.text();
            
            // Handle Tool Calling
            const functionCalls = result.response.functionCalls();
            if (functionCalls && functionCalls.length > 0) {
                const call = functionCalls[0];
                const toolResult = await this.executeTool(userId, call.name, call.args);
                
                // Save the function call to DB (optional, but good for completeness if we want to restore history properly later, though Gemini SDK manages state in memory during `sendMessage`. We will save just the response for history reconstruction).
                await AiChatMessage.create({
                    sessionId: session._id,
                    role: 'function',
                    content: JSON.stringify(toolResult),
                    functionCallName: call.name
                });

                // Send the tool response back to the model
                result = await chat.sendMessage([{
                    functionResponse: {
                        name: call.name,
                        response: toolResult
                    }
                }]);
                responseText = result.response.text();
            }

            // Save Model Response
            if (responseText) {
                await AiChatMessage.create({
                    sessionId: session._id,
                    role: 'model',
                    content: responseText
                });
            }

            return { reply: responseText, sessionId: session._id.toString() };
        } catch (error: any) {
            console.error('[AI Chat Error]', error);
            throw new Error('Failed to generate response from AI.');
        }
    }

    static async getSessions(userId: string) {
        return await AiChatSession.find({ userId }).sort({ updatedAt: -1 });
    }

    static async getSessionHistory(userId: string, sessionId: string) {
        const session = await AiChatSession.findOne({ _id: sessionId, userId });
        if (!session) throw new Error('Session not found');
        return await AiChatMessage.find({ sessionId }).sort({ createdAt: 1 });
    }

    // --- Tool Execution Logic ---

    private static async executeTool(userId: string, name: string, args: any): Promise<any> {
        try {
            switch (name) {
                case 'get_financial_summary':
                    return await this.getFinancialSummary(userId);
                case 'get_recent_transactions':
                    return await this.getRecentTransactions(userId, args.limit);
                case 'get_savings_goals':
                    return await this.getSavingsGoals(userId);
                case 'get_debts':
                    return await this.getDebts(userId);
                default:
                    return { error: `Function ${name} not found` };
            }
        } catch (error: any) {
            console.error(`[Tool Execution Error] ${name}:`, error);
            return { error: `Failed to execute ${name}: ${error.message}` };
        }
    }

    private static async getFinancialSummary(userId: string) {
        const user = await User.findById(userId);
        if (!user) return { error: 'User not found' };

        const balance = user.balance;

        // Current month expenses
        const now = new Date();
        const firstDayOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
        
        const transactions = await Transaction.aggregate([
            {
                $match: {
                    userId: userId,
                    createdAt: { $gte: firstDayOfMonth },
                    type: { $in: ['EXPENSE_PAYMENT', 'SUBSCRIPTION_FEE', 'TRANSFER_SENT', 'WITHDRAWAL'] }
                }
            },
            {
                $group: {
                    _id: null,
                    totalExpenses: { $sum: '$amount' }
                }
            }
        ]);
        const totalExpensesThisMonth = transactions.length > 0 ? parseFloat(transactions[0].totalExpenses.toString()) : 0;

        // Savings
        const goals = await SavingsGoal.find({ userId, status: 'ACTIVE' });
        const totalSavings = goals.reduce((sum, g) => sum + parseFloat(g.currentAmount.toString()), 0);

        // Debts
        const debtsToPay = await OriginalDebt.aggregate([
            { $match: { debtorId: userId, remainingAmount: { $gt: 0 } } },
            { $group: { _id: null, total: { $sum: '$remainingAmount' } } }
        ]);
        const totalDebtToPay = debtsToPay.length > 0 ? debtsToPay[0].total : 0;

        return {
            balance,
            currency: user.currency,
            totalExpensesThisMonth,
            totalSavings,
            totalDebtToPay
        };
    }

    private static async getRecentTransactions(userId: string, limit: number = 5) {
        const _limit = Math.min(Math.max(limit, 1), 20);
        const txs = await Transaction.find({ userId })
            .sort({ createdAt: -1 })
            .limit(_limit)
            .select('type amount currency createdAt description');
        
        return txs.map(t => ({
            type: t.type,
            amount: parseFloat(t.amount.toString()),
            currency: t.currency,
            date: t.createdAt.toISOString().slice(0, 10),
            description: t.description || 'No description'
        }));
    }

    private static async getSavingsGoals(userId: string) {
        const goals = await SavingsGoal.find({ userId, status: 'ACTIVE' })
            .select('name targetAmount currentAmount deadline');
            
        return goals.map(g => ({
            name: g.name,
            targetAmount: parseFloat(g.targetAmount.toString()),
            currentAmount: parseFloat(g.currentAmount.toString()),
            deadline: g.deadline ? g.deadline.toISOString().slice(0, 10) : 'No deadline'
        }));
    }

    private static async getDebts(userId: string) {
        const [payable, receivable] = await Promise.all([
            OriginalDebt.find({ debtorId: userId, remainingAmount: { $gt: 0 } }).populate('creditorId', 'displayName'),
            OriginalDebt.find({ creditorId: userId, remainingAmount: { $gt: 0 } }).populate('debtorId', 'displayName')
        ]);

        return {
            youOweOthers: payable.map(d => ({
                to: (d.creditorId as any)?.displayName || 'Unknown',
                amount: d.remainingAmount,
                originalAmount: d.originalAmount
            })),
            othersOweYou: receivable.map(d => ({
                from: (d.debtorId as any)?.displayName || 'Unknown',
                amount: d.remainingAmount,
                originalAmount: d.originalAmount
            }))
        };
    }
}
