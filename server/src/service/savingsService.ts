// server/src/service/savingsService.ts
import mongoose from 'mongoose';
import { SavingsGoal, ISavingsGoal } from '../models/SavingsGoal';
import { SavingsDeposit, ISavingsDeposit } from '../models/SavingsDeposit';
import { User } from '../models/User';
import { transactionService } from './transactionService';
import { notificationService } from './notificationService';
import { TransactionType } from '../type/transaction';
import { NotificationType } from '../models/Notification';

// ── Interest Rate Tier Matrix ──────────────────────────────────────────────────

interface InterestTier {
    minAmount: number;
    term: number;      // days: 0=flexible, 30, 90, 180, 365
    annualRate: number; // %
}

const INTEREST_TIERS: InterestTier[] = [
    // ── Không kỳ hạn (flexible) ──
    { minAmount: 0,          term: 0,   annualRate: 0.5  },
    { minAmount: 5_000_000,  term: 0,   annualRate: 0.8  },
    { minAmount: 50_000_000, term: 0,   annualRate: 1.0  },

    // ── 1 tháng ──
    { minAmount: 0,          term: 30,  annualRate: 3.0  },
    { minAmount: 5_000_000,  term: 30,  annualRate: 3.3  },
    { minAmount: 50_000_000, term: 30,  annualRate: 3.5  },

    // ── 3 tháng ──
    { minAmount: 0,          term: 90,  annualRate: 3.8  },
    { minAmount: 5_000_000,  term: 90,  annualRate: 4.2  },
    { minAmount: 50_000_000, term: 90,  annualRate: 4.5  },

    // ── 6 tháng ──
    { minAmount: 0,          term: 180, annualRate: 4.5  },
    { minAmount: 5_000_000,  term: 180, annualRate: 5.0  },
    { minAmount: 50_000_000, term: 180, annualRate: 5.5  },

    // ── 12 tháng (365 days = true year) ──
    { minAmount: 0,          term: 365, annualRate: 5.5  },
    { minAmount: 5_000_000,  term: 365, annualRate: 6.0  },
    { minAmount: 50_000_000, term: 365, annualRate: 6.5  },
];

const VALID_TERMS = [0, 30, 90, 180, 365];
const TERM_LABELS: Record<number, string> = {
    0: 'Flexible',
    30: '1 Month',
    90: '3 Months',
    180: '6 Months',
    365: '12 Months',
};

// ── Helpers ────────────────────────────────────────────────────────────────────

function addDays(base: Date, n: number): Date {
    const d = new Date(base);
    d.setDate(d.getDate() + n);
    return d;
}

/**
 * Look up the best matching annual interest rate for a given amount and term.
 */
function getRate(amount: number, termDays: number): number {
    const matching = INTEREST_TIERS
        .filter(t => t.term === termDays && amount >= t.minAmount)
        .sort((a, b) => b.minAmount - a.minAmount);
    return matching[0]?.annualRate ?? 0;
}

/**
 * Simple interest calculation (VN banking style).
 *   Interest = principal × (annualRate / 100) × (daysHeld / 365)
 */
function calculateInterest(
    principal: number,
    annualRate: number,
    depositDate: Date,
    asOfDate: Date = new Date(),
): number {
    const daysHeld = Math.floor(
        (asOfDate.getTime() - depositDate.getTime()) / (1000 * 60 * 60 * 24),
    );
    if (daysHeld <= 0) return 0;
    return Math.round(principal * (annualRate / 100) * (daysHeld / 365));
}

// ── Unified Interest Helpers ───────────────────────────────────────────────────

/**
 * Resolve the maturity date for a deposit.
 * Returns null for flexible (no-term) deposits.
 */
function getMaturityDate(deposit: any): Date | null {
    if (!deposit.term || deposit.term <= 0) return null;
    return deposit.maturityDate
        ? new Date(deposit.maturityDate)
        : addDays(new Date(deposit.depositDate), deposit.term);
}

/**
 * Unified interest calculation for a deposit.
 * - Caps interest at maturity date for fixed-term deposits.
 * - Uses penalty (flexible) rate for early withdrawal.
 */
function calculateDepositInterest(
    deposit: any,
    asOfDate: Date = new Date(),
    options: { forWithdrawal?: boolean } = {},
): number {
    const principal = d128(deposit.amount);
    const depositDate = new Date(deposit.depositDate);
    const maturityDate = getMaturityDate(deposit);

    // Flexible deposit: interest accrues indefinitely at flexible rate
    if (!maturityDate) {
        return calculateInterest(principal, deposit.annualRate, depositDate, asOfDate);
    }

    const isBeforeMaturity = asOfDate < maturityDate;

    // Determine effective rate
    // Early withdrawal (before maturity) → penalty: flexible rate only
    const rate = (options.forWithdrawal && isBeforeMaturity)
        ? getRate(principal, 0)
        : deposit.annualRate;

    // Fixed-term: interest stops accruing at maturity date
    const interestEndDate = isBeforeMaturity ? asOfDate : maturityDate;

    return calculateInterest(principal, rate, depositDate, interestEndDate);
}

// ── Transform helpers ──────────────────────────────────────────────────────────

function d128(v: any): number {
    if (v && typeof v === 'object' && typeof v.toString === 'function') {
        return parseFloat(v.toString());
    }
    return Number(v ?? 0);
}

function transformGoal(goal: any) {
    return {
        id: goal._id.toString(),
        userId: goal.userId,
        name: goal.name,
        targetAmount: d128(goal.targetAmount),
        currentAmount: d128(goal.currentAmount),
        icon: goal.icon,
        status: goal.status,
        deadline: goal.deadline,
        createdAt: goal.createdAt,
        updatedAt: goal.updatedAt,
    };
}

function transformDeposit(deposit: any) {
    const principal = d128(deposit.amount);
    const rate = deposit.annualRate;

    // For WITHDRAWN or MATURED: use the frozen accruedInterest value
    // For HOLDING: calculate live interest
    let withdrawableInterest: number;
    let projectedInterest: number | null = null;

    if (deposit.status === 'WITHDRAWN' || deposit.status === 'MATURED') {
        withdrawableInterest = d128(deposit.accruedInterest);
    } else {
        // Live interest user would receive if withdrawing NOW
        withdrawableInterest = calculateDepositInterest(deposit, new Date(), { forWithdrawal: true });

        // Projected interest at maturity (only for fixed-term deposits)
        const maturityDate = getMaturityDate(deposit);
        if (maturityDate) {
            projectedInterest = calculateDepositInterest(deposit, maturityDate);
        }
    }

    return {
        id: deposit._id.toString(),
        goalId: deposit.goalId?.toString?.() ?? deposit.goalId,
        userId: deposit.userId,
        amount: principal,
        term: deposit.term,
        termLabel: TERM_LABELS[deposit.term] ?? `${deposit.term}d`,
        annualRate: rate,
        accruedInterest: withdrawableInterest,
        projectedInterest,
        status: deposit.status,
        depositDate: deposit.depositDate,
        maturityDate: deposit.maturityDate,
        withdrawnAt: deposit.withdrawnAt,
        createdAt: deposit.createdAt,
    };
}

// ── Public Service ─────────────────────────────────────────────────────────────

export const savingsService = {

    // ── CRUD Goals ────────────────────────────────────────────────────────────

    async createGoal(
        userId: string,
        data: { name: string; targetAmount: number; icon?: string; deadline?: string },
    ) {
        if (!data.name || data.name.trim().length === 0) {
            throw new Error('Goal name is required');
        }
        if (!data.targetAmount || data.targetAmount <= 0) {
            throw new Error('Target amount must be positive');
        }

        const goal = await SavingsGoal.create({
            userId,
            name: data.name.trim(),
            targetAmount: data.targetAmount,
            icon: data.icon || '🎯',
            deadline: data.deadline ? new Date(data.deadline) : undefined,
        });

        return transformGoal(goal.toJSON());
    },

    async getGoals(userId: string) {
        const goals = await SavingsGoal.find({ userId })
            .sort({ createdAt: -1 })
            .lean();

        const goalIds = goals.map(g => g._id);
        const deposits = await SavingsDeposit.find({
            goalId: { $in: goalIds },
            userId,
        })
            .sort({ depositDate: -1 })
            .lean();

        // Group deposits by goalId
        const depositsByGoal = new Map<string, any[]>();
        for (const d of deposits) {
            const gid = d.goalId.toString();
            if (!depositsByGoal.has(gid)) depositsByGoal.set(gid, []);
            depositsByGoal.get(gid)!.push(transformDeposit(d));
        }

        // Aggregate totals
        let totalSavings = 0;
        let totalInterest = 0;

        const result = goals.map(g => {
            const gd = depositsByGoal.get(g._id.toString()) || [];
            const activeDeposits = gd.filter(d => d.status !== 'WITHDRAWN');
            const goalTotal = activeDeposits.reduce((s, d) => s + d.amount + d.accruedInterest, 0);
            totalSavings += activeDeposits.reduce((s, d) => s + d.amount, 0);
            totalInterest += activeDeposits.reduce((s, d) => s + d.accruedInterest, 0);

            return {
                ...transformGoal(g),
                deposits: gd,
                totalWithInterest: goalTotal,
                depositCount: activeDeposits.length,
            };
        });

        return {
            goals: result,
            summary: {
                totalGoals: goals.length,
                activeGoals: goals.filter(g => g.status === 'ACTIVE').length,
                totalSavings: Math.round(totalSavings),
                totalInterest: Math.round(totalInterest),
                totalBalance: Math.round(totalSavings + totalInterest),
            },
        };
    },

    async getGoalById(goalId: string, userId: string) {
        const goal = await SavingsGoal.findOne({ _id: goalId, userId }).lean();
        if (!goal) throw new Error('Savings goal not found');

        const deposits = await SavingsDeposit.find({ goalId, userId })
            .sort({ depositDate: -1 })
            .lean();

        const transformed = deposits.map(transformDeposit);
        const activeDeposits = transformed.filter(d => d.status !== 'WITHDRAWN');
        const totalWithInterest = activeDeposits.reduce(
            (s, d) => s + d.amount + d.accruedInterest, 0,
        );

        return {
            ...transformGoal(goal),
            deposits: transformed,
            totalWithInterest,
            depositCount: activeDeposits.length,
        };
    },

    async updateGoal(
        goalId: string,
        userId: string,
        data: { name?: string; targetAmount?: number; icon?: string; deadline?: string | null },
    ) {
        const goal = await SavingsGoal.findOne({ _id: goalId, userId });
        if (!goal) throw new Error('Savings goal not found');
        if (goal.status !== 'ACTIVE') throw new Error('Cannot update a non-active goal');

        if (data.name !== undefined) goal.name = data.name.trim();
        if (data.targetAmount !== undefined) {
            if (data.targetAmount <= 0) throw new Error('Target amount must be positive');
            (goal as any).targetAmount = data.targetAmount;
        }
        if (data.icon !== undefined) goal.icon = data.icon;
        if (data.deadline !== undefined) {
            goal.deadline = data.deadline ? new Date(data.deadline) : undefined;
        }

        await goal.save();
        return transformGoal(goal.toJSON());
    },

    async cancelGoal(goalId: string, userId: string) {
        const goal = await SavingsGoal.findOne({ _id: goalId, userId });
        if (!goal) throw new Error('Savings goal not found');
        if (goal.status !== 'ACTIVE') throw new Error('Goal is already closed');

        // Check for active deposits — must withdraw all first
        const activeDeposits = await SavingsDeposit.countDocuments({
            goalId,
            userId,
            status: { $in: ['HOLDING', 'MATURED'] },
        });

        if (activeDeposits > 0) {
            throw new Error(
                `Cannot cancel goal with ${activeDeposits} active deposit(s). Withdraw all deposits first.`,
            );
        }

        goal.status = 'CANCELLED';
        await goal.save();
        return transformGoal(goal.toJSON());
    },

    // ── Deposit Operations ────────────────────────────────────────────────────

    async createDeposit(
        goalId: string,
        userId: string,
        data: { amount: number; term: number },
    ) {
        const { amount, term } = data;

        // Validate
        if (!amount || amount <= 0) throw new Error('Deposit amount must be positive');
        if (!VALID_TERMS.includes(term)) {
            throw new Error(`Invalid term. Valid options: ${VALID_TERMS.join(', ')} days`);
        }

        const goal = await SavingsGoal.findOne({ _id: goalId, userId });
        if (!goal) throw new Error('Savings goal not found');
        if (goal.status !== 'ACTIVE') throw new Error('Cannot deposit to a non-active goal');

        // Determine rate
        const annualRate = getRate(amount, term);
        const depositDate = new Date();
        const maturityDate = term > 0 ? addDays(depositDate, term) : undefined;

        const session = await mongoose.startSession();
        let result: any = null;

        try {
            await session.withTransaction(async () => {
                // 1. Verify balance
                const user = await User.findById(userId).session(session);
                if (!user) throw new Error('User not found');
                const balance = d128(user.balance);
                if (balance < amount) {
                    throw new Error(
                        `Insufficient balance. Available: ${balance.toLocaleString()} VND, Required: ${amount.toLocaleString()} VND`,
                    );
                }

                // 2. Deduct from wallet
                await User.updateOne(
                    { _id: userId },
                    { $inc: { balance: -amount } },
                    { session },
                );

                // 3. Create deposit record
                const [deposit] = await SavingsDeposit.create([{
                    goalId,
                    userId,
                    amount,
                    term,
                    annualRate,
                    accruedInterest: 0,
                    status: 'HOLDING',
                    depositDate,
                    maturityDate,
                }], { session });

                // 4. Update goal currentAmount
                await SavingsGoal.updateOne(
                    { _id: goalId },
                    { $inc: { currentAmount: amount } },
                    { session },
                );

                // 5. Create transaction record
                await transactionService.createTransaction({
                    userId,
                    type: TransactionType.SAVINGS_DEPOSIT,
                    amount,
                    balanceBefore: balance,
                    balanceAfter: balance - amount,
                    currency: 'VND',
                    description: `Savings deposit to "${goal.name}" (${TERM_LABELS[term] ?? term + 'd'} @ ${annualRate}%/yr)`,
                    referenceId: deposit._id.toString(),
                    referenceType: 'SAVINGS_DEPOSIT',
                    session,
                });

                result = transformDeposit(deposit.toJSON());
            });
        } finally {
            await session.endSession();
        }

        // 6. Check goal completion (outside transaction for notifications)
        const updatedGoal = await SavingsGoal.findById(goalId).lean();
        if (updatedGoal) {
            const current = d128(updatedGoal.currentAmount);
            const target = d128(updatedGoal.targetAmount);
            if (current >= target && updatedGoal.status === 'ACTIVE') {
                await SavingsGoal.updateOne({ _id: goalId }, { status: 'COMPLETED' });
                await notificationService.createNotification({
                    userId,
                    type: NotificationType.SAVINGS_GOAL_COMPLETED,
                    title: '🎉 Savings Goal Completed!',
                    message: `Congratulations! You reached your savings goal "${updatedGoal.name}" (${target.toLocaleString()} VND)`,
                    data: { goalId, goalName: updatedGoal.name, targetAmount: target },
                });
            }
        }

        return result;
    },

    async withdrawDeposit(depositId: string, userId: string) {
        const deposit = await SavingsDeposit.findOne({ _id: depositId, userId });
        if (!deposit) throw new Error('Deposit not found');
        if (deposit.status === 'WITHDRAWN') throw new Error('Deposit already withdrawn');

        const principal = d128(deposit.amount);
        const interest = calculateDepositInterest(deposit, new Date(), { forWithdrawal: true });
        const totalPayout = principal + interest;

        // Check if early withdrawal (before maturity)
        const maturityDate = getMaturityDate(deposit);
        const isEarly = deposit.term > 0 && maturityDate != null && new Date() < maturityDate;
        const effectiveRate = isEarly ? getRate(principal, 0) : deposit.annualRate;

        const session = await mongoose.startSession();
        let result: any = null;

        try {
            await session.withTransaction(async () => {
                // 1. Get current balance
                const user = await User.findById(userId).session(session);
                if (!user) throw new Error('User not found');
                const balance = d128(user.balance);

                // 2. Credit wallet (principal + interest)
                await User.updateOne(
                    { _id: userId },
                    { $inc: { balance: totalPayout } },
                    { session },
                );

                // 3. Update deposit status
                await SavingsDeposit.updateOne(
                    { _id: depositId },
                    {
                        status: 'WITHDRAWN',
                        accruedInterest: interest,
                        withdrawnAt: new Date(),
                    },
                    { session },
                );

                // 4. Update goal currentAmount (subtract principal only)
                await SavingsGoal.updateOne(
                    { _id: deposit.goalId },
                    { $inc: { currentAmount: -principal } },
                    { session },
                );

                // 5. Create transaction
                const desc = isEarly
                    ? `Early withdrawal from savings (penalty rate: ${effectiveRate}%/yr)`
                    : `Savings withdrawal + interest (${deposit.annualRate}%/yr)`;

                await transactionService.createTransaction({
                    userId,
                    type: TransactionType.SAVINGS_WITHDRAW,
                    amount: totalPayout,
                    balanceBefore: balance,
                    balanceAfter: balance + totalPayout,
                    currency: 'VND',
                    description: desc,
                    referenceId: depositId,
                    referenceType: 'SAVINGS_WITHDRAW',
                    session,
                });

                result = {
                    depositId,
                    principal,
                    interest,
                    effectiveRate,
                    totalPayout,
                    isEarlyWithdrawal: isEarly,
                    originalRate: deposit.annualRate,
                };
            });
        } finally {
            await session.endSession();
        }

        return result;
    },

    // ── Interest Preview ──────────────────────────────────────────────────────

    getInterestPreview(amount: number, term: number) {
        if (!VALID_TERMS.includes(term)) {
            throw new Error(`Invalid term. Valid options: ${VALID_TERMS.join(', ')} days`);
        }
        if (!amount || amount <= 0) {
            throw new Error('Amount must be positive');
        }

        const annualRate = getRate(amount, term);
        const daysForCalc = term > 0 ? term : 30; // preview 30 days for flexible
        const estimatedInterest = Math.round(
            amount * (annualRate / 100) * (daysForCalc / 365),
        );
        const maturityDate = term > 0 ? addDays(new Date(), term) : null;

        return {
            amount,
            term,
            termLabel: TERM_LABELS[term] ?? `${term}d`,
            annualRate,
            estimatedInterest,
            maturityDate,
            interestTiers: INTEREST_TIERS,
        };
    },

    // ── Goal Projection ───────────────────────────────────────────────────────

    async getGoalProjection(goalId: string, userId: string) {
        const goal = await SavingsGoal.findOne({ _id: goalId, userId }).lean();
        if (!goal) throw new Error('Savings goal not found');

        const deposits = await SavingsDeposit.find({
            goalId,
            userId,
            status: { $in: ['HOLDING', 'MATURED'] },
        }).lean();

        const targetAmount = d128(goal.targetAmount);
        let currentPrincipal = 0;
        let currentInterest = 0;
        const upcomingMaturities: any[] = [];

        for (const dep of deposits) {
            const principal = d128(dep.amount);
            const interest = calculateInterest(
                principal,
                dep.annualRate,
                new Date(dep.depositDate),
            );
            currentPrincipal += principal;
            currentInterest += interest;

            if (dep.maturityDate && dep.status === 'HOLDING') {
                const matDate = new Date(dep.maturityDate);
                if (matDate > new Date()) {
                    const fullInterest = calculateInterest(
                        principal,
                        dep.annualRate,
                        new Date(dep.depositDate),
                        matDate,
                    );
                    upcomingMaturities.push({
                        depositId: dep._id.toString(),
                        maturityDate: dep.maturityDate,
                        principal,
                        estimatedInterest: fullInterest,
                        totalPayout: principal + fullInterest,
                    });
                }
            }
        }

        const currentTotal = currentPrincipal + currentInterest;
        const remaining = Math.max(0, targetAmount - currentPrincipal);
        const progressPercent = targetAmount > 0
            ? Math.min(100, Math.round((currentPrincipal / targetAmount) * 100))
            : 0;

        // Estimate completion: if user keeps depositing at their average rate
        let estimatedCompletionDate: string | null = null;
        let monthlyNeeded: number | null = null;

        if (remaining > 0 && goal.deadline) {
            const daysUntilDeadline = Math.floor(
                (new Date(goal.deadline).getTime() - Date.now()) / (1000 * 60 * 60 * 24),
            );
            if (daysUntilDeadline > 0) {
                monthlyNeeded = Math.ceil(remaining / (daysUntilDeadline / 30));
            }
        }

        // Simple projection based on average deposit rate
        if (remaining > 0 && deposits.length > 0) {
            const firstDepositDate = new Date(
                Math.min(...deposits.map(d => new Date(d.depositDate).getTime())),
            );
            const daysActive = Math.max(
                1,
                (Date.now() - firstDepositDate.getTime()) / (1000 * 60 * 60 * 24),
            );
            const dailyRate = currentPrincipal / daysActive;
            if (dailyRate > 0) {
                const daysToComplete = Math.ceil(remaining / dailyRate);
                const completionDate = addDays(new Date(), daysToComplete);
                estimatedCompletionDate = completionDate.toISOString().slice(0, 10);
            }
        }

        return {
            goalId,
            goalName: goal.name,
            targetAmount,
            currentPrincipal: Math.round(currentPrincipal),
            currentInterest: Math.round(currentInterest),
            currentTotal: Math.round(currentTotal),
            remaining: Math.round(remaining),
            progressPercent,
            estimatedCompletionDate,
            monthlyNeeded: monthlyNeeded ? Math.round(monthlyNeeded) : null,
            upcomingMaturities: upcomingMaturities.sort(
                (a, b) => new Date(a.maturityDate).getTime() - new Date(b.maturityDate).getTime(),
            ),
            deadline: goal.deadline,
        };
    },

    // ── Maturity Processing (for cron/scheduled tasks) ────────────────────────

    async processMaturedDeposits() {
        const now = new Date();
        const matured = await SavingsDeposit.find({
            status: 'HOLDING',
            term: { $gt: 0 },
            maturityDate: { $lte: now },
        }).lean();

        let processed = 0;
        for (const dep of matured) {
            // Calculate interest capped at maturity date and freeze it
            const maturityInterest = calculateDepositInterest(
                dep,
                new Date(dep.maturityDate!),
            );

            await SavingsDeposit.updateOne(
                { _id: dep._id },
                {
                    status: 'MATURED',
                    accruedInterest: maturityInterest,
                },
            );

            const principal = d128(dep.amount);
            const interest = calculateInterest(
                principal,
                dep.annualRate,
                new Date(dep.depositDate),
                new Date(dep.maturityDate!),
            );

            // Notify user
            await notificationService.createNotification({
                userId: dep.userId,
                type: NotificationType.SAVINGS_DEPOSIT_MATURED,
                title: '🏦 Deposit Matured',
                message: `Your ${TERM_LABELS[dep.term] ?? dep.term + '-day'} deposit of ${principal.toLocaleString()} VND has matured! Interest earned: ${interest.toLocaleString()} VND`,
                data: {
                    depositId: dep._id.toString(),
                    goalId: dep.goalId.toString(),
                    principal,
                    interest,
                    totalPayout: principal + interest,
                },
            });

            processed++;
        }

        return { processed };
    },

    // ── Cross-Module: Forecast Events ─────────────────────────────────────────

    async getUpcomingMaturities(userId: string, horizonDays: number = 30) {
        const today = new Date();
        const horizon = addDays(today, horizonDays);

        const deposits = await SavingsDeposit.find({
            userId,
            status: 'HOLDING',
            term: { $gt: 0 },
            maturityDate: { $gte: today, $lte: horizon },
        }).populate<{ goalId: { name: string } }>({
            path: 'goalId',
            select: 'name',
        }).lean();

        return deposits.map(dep => {
            const principal = d128(dep.amount);
            const interest = calculateInterest(
                principal,
                dep.annualRate,
                new Date(dep.depositDate),
                new Date(dep.maturityDate!),
            );
            const goalName = (dep.goalId as any)?.name ?? 'Savings';

            return {
                depositId: dep._id.toString(),
                goalName,
                principal,
                interest,
                totalPayout: principal + interest,
                maturityDate: dep.maturityDate,
                term: dep.term,
                annualRate: dep.annualRate,
            };
        });
    },

    // ── Cross-Module: Report Summary ──────────────────────────────────────────

    async getSavingsSummaryForReport(userId: string, month: string) {
        if (!/^\d{4}-\d{2}$/.test(month)) {
            throw new Error('Invalid month format. Use YYYY-MM');
        }

        const [year, m] = month.split('-').map(Number);
        const startOfMonth = new Date(Date.UTC(year, m - 1, 1));
        const endOfMonth = new Date(Date.UTC(year, m, 1));

        // Deposits made in this month
        const depositsInMonth = await SavingsDeposit.find({
            userId,
            depositDate: { $gte: startOfMonth, $lt: endOfMonth },
        }).lean();

        const totalDeposited = depositsInMonth.reduce(
            (s, d) => s + d128(d.amount), 0,
        );

        // Withdrawals in this month
        const withdrawalsInMonth = await SavingsDeposit.find({
            userId,
            status: 'WITHDRAWN',
            withdrawnAt: { $gte: startOfMonth, $lt: endOfMonth },
        }).lean();

        let totalWithdrawn = 0;
        let interestEarned = 0;
        for (const w of withdrawalsInMonth) {
            totalWithdrawn += d128(w.amount);
            interestEarned += d128(w.accruedInterest);
        }

        // Active goals count
        const activeGoals = await SavingsGoal.countDocuments({
            userId,
            status: 'ACTIVE',
        });

        return {
            totalDeposited: Math.round(totalDeposited),
            totalWithdrawn: Math.round(totalWithdrawn),
            interestEarned: Math.round(interestEarned),
            activeGoals,
            netSavingsFlow: Math.round(totalDeposited - totalWithdrawn),
        };
    },
};
