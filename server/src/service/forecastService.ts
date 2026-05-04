// server/src/service/forecastService.ts
import mongoose from 'mongoose';
import { User } from '../models/User';
import { SubscriptionMember } from '../models/SubscriptionMember';
import { Subscription } from '../models/Subscription';
import { Transfer } from '../models/Transfer';
import { Transaction } from '../models/Transaction';
import { PaymentRequest } from '../models/PaymentRequest';
import {
    ForecastEvent,
    DailyForecast,
    ForecastAlert,
    ForecastSummary,
    ForecastResponse,
    SpendingInsight,
    CategoryBreakdown,
    SmartTip,
} from '../type/forecast';

// ── Helpers ────────────────────────────────────────────────────────────────────

function toDateKey(d: Date): string {
    return d.toISOString().slice(0, 10); // yyyy-MM-dd
}

function addDays(base: Date, n: number): Date {
    const d = new Date(base);
    d.setDate(d.getDate() + n);
    return d;
}

function startOfDay(d: Date): Date {
    return new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
}

const OUTFLOW_TYPES = new Set([
    'WITHDRAWAL',
    'TRANSFER_SENT',
    'TRANSFER_REFUND_SENT',
    'SUBSCRIPTION_FEE',
    'SETTLEMENT_SENT',
    'EXPENSE_PAYMENT',
    'VNPAY_PAYMENT',
]);

const CATEGORY_LABELS: Record<string, string> = {
    WITHDRAWAL: 'Withdrawals',
    TRANSFER_SENT: 'Transfers sent',
    TRANSFER_REFUND_SENT: 'Transfer refunds',
    SUBSCRIPTION_FEE: 'Subscriptions',
    SETTLEMENT_SENT: 'Settlements',
    EXPENSE_PAYMENT: 'Expense payments',
    VNPAY_PAYMENT: 'VNPay payments',
};

const DAY_NAMES = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

// ── Core builder ───────────────────────────────────────────────────────────────

/**
 * Build all ForecastEvent[] for the given user within horizonDays.
 */
async function buildForecastEvents(
    userId: string,
    horizonDays: number,
): Promise<ForecastEvent[]> {
    const now = new Date();
    const today = startOfDay(now);
    const horizon = addDays(today, horizonDays);
    const events: ForecastEvent[] = [];

    // ── 1. Subscription members ──────────────────────────────────────────────
    const members = await SubscriptionMember.find({
        userId,
        status: 'ACTIVE',
    }).populate<{ subscriptionId: { _id: mongoose.Types.ObjectId; name: string; status: string; currency: string; groupId: string; groupName?: string } }>({
        path: 'subscriptionId',
        select: 'name status currency groupId groupName',
    });

    for (const m of members) {
        const sub = m.subscriptionId as any;
        if (!sub || sub.status !== 'ACTIVE') continue;

        const nbd: Date = m.nextBillingDate;
        if (!nbd) continue;

        // Treat overdue (past nextBillingDate) as effective today
        const effectiveDate = nbd < today ? today : startOfDay(nbd);
        if (effectiveDate > horizon) continue;

        events.push({
            id: `sub_member_${m._id}`,
            sourceType: 'SUBSCRIPTION',
            sourceId: m._id.toString(),
            direction: 'OUTFLOW',
            certainty: 'CONFIRMED',
            amount: Number(m.amount),
            currency: sub.currency ?? 'VND',
            effectiveDate,
            title: sub.name ?? 'Subscription',
            groupName: sub.groupName ?? undefined,
            actionType: 'OPEN_SUBSCRIPTION',
            status: 'ACTIVE',
            retryCount: m.retryCount ?? 0,
        });
    }

    // ── 2. Outgoing pending transfers ─────────────────────────────────────────
    const outgoing = await Transfer.find({
        fromUserId: userId,
        status: 'PENDING',
    }).lean();

    for (const t of outgoing) {
        let effectiveDate: Date = today;
        if ((t as any).paymentRequestId) {
            const pr = await PaymentRequest.findById((t as any).paymentRequestId)
                .select('expiresAt status')
                .lean();
            if (pr && pr.status === 'CANCELLED') continue;
            if (pr && (pr as any).expiresAt) {
                effectiveDate = startOfDay(new Date((pr as any).expiresAt));
            } else {
                effectiveDate = startOfDay(addDays(new Date((t as any).createdAt || now), 14));
            }
        } else {
            effectiveDate = startOfDay(addDays(new Date((t as any).createdAt || now), 14));
        }
        if (effectiveDate > horizon) continue;

        // Resolve counterparty display name
        let counterparty: string | undefined;
        try {
            const toUser = await User.findById((t as any).toUserId).select('displayName email').lean();
            counterparty = (toUser as any)?.displayName ?? (toUser as any)?.email ?? undefined;
        } catch {}

        events.push({
            id: `transfer_out_${t._id}`,
            sourceType: 'TRANSFER_OUT',
            sourceId: t._id.toString(),
            direction: 'OUTFLOW',
            certainty: 'COMMITTED',
            amount: Number((t as any).amount),
            currency: (t as any).currency ?? 'VND',
            effectiveDate,
            title: counterparty ? `Payment to ${counterparty}` : 'Outgoing payment',
            counterparty,
            actionType: 'OPEN_TRANSFER',
            status: (t as any).status,
        });
    }

    // ── 3. Incoming pending transfers ─────────────────────────────────────────
    const incoming = await Transfer.find({
        toUserId: userId,
        status: 'PENDING',
    }).lean();

    for (const t of incoming) {
        if ((t as any).fromUserId === userId) continue; // self-transfer guard

        let effectiveDate: Date = today;
        if ((t as any).paymentRequestId) {
            const pr = await PaymentRequest.findById((t as any).paymentRequestId)
                .select('expiresAt status')
                .lean();
            if (pr && pr.status === 'CANCELLED') continue;
            if (pr && (pr as any).expiresAt) {
                effectiveDate = startOfDay(new Date((pr as any).expiresAt));
            } else {
                effectiveDate = startOfDay(addDays(new Date((t as any).createdAt || now), 14));
            }
        } else {
            effectiveDate = startOfDay(addDays(new Date((t as any).createdAt || now), 14));
        }
        if (effectiveDate > horizon) continue;

        let counterparty: string | undefined;
        try {
            const fromUser = await User.findById((t as any).fromUserId).select('displayName email').lean();
            counterparty = (fromUser as any)?.displayName ?? (fromUser as any)?.email ?? undefined;
        } catch {}

        events.push({
            id: `transfer_in_${t._id}`,
            sourceType: 'TRANSFER_IN',
            sourceId: t._id.toString(),
            direction: 'INFLOW',
            certainty: 'EXPECTED',
            amount: Number((t as any).amount),
            currency: (t as any).currency ?? 'VND',
            effectiveDate,
            title: counterparty ? `Payment from ${counterparty}` : 'Incoming payment',
            counterparty,
            actionType: 'OPEN_TRANSFER',
            status: (t as any).status,
        });
    }

    return events;
}

// ── Balance simulation ─────────────────────────────────────────────────────────

function simulateBalance(
    currentBalance: number,
    events: ForecastEvent[],
    horizonDays: number,
): DailyForecast[] {
    const today = startOfDay(new Date());
    const dailyMap = new Map<string, { outflows: ForecastEvent[]; inflows: ForecastEvent[] }>();

    // Pre-populate all days
    for (let i = 0; i <= horizonDays; i++) {
        const d = toDateKey(addDays(today, i));
        dailyMap.set(d, { outflows: [], inflows: [] });
    }

    // Bucket events into days
    for (const e of events) {
        const key = toDateKey(e.effectiveDate);
        const bucket = dailyMap.get(key);
        if (!bucket) continue;
        if (e.direction === 'OUTFLOW') bucket.outflows.push(e);
        else bucket.inflows.push(e);
    }

    const result: DailyForecast[] = [];
    let openingSafe = currentBalance;

    const sortedKeys = [...dailyMap.keys()].sort();
    for (const dateKey of sortedKeys) {
        const { outflows, inflows } = dailyMap.get(dateKey)!;

        const safeOut = outflows
            .filter(e => e.certainty === 'CONFIRMED' || e.certainty === 'COMMITTED')
            .reduce((s, e) => s + e.amount, 0);

        const expectedIn = inflows
            .filter(e => e.certainty === 'EXPECTED')
            .reduce((s, e) => s + e.amount, 0);

        const closingSafe = openingSafe - safeOut;
        const closingExpected = closingSafe + expectedIn;

        result.push({
            date: dateKey,
            openingBalance: openingSafe,
            outflows,
            inflows,
            closingBalanceSafe: closingSafe,
            closingBalanceExpected: closingExpected,
        });

        openingSafe = closingSafe; // expected does NOT carry over
    }

    return result;
}

// ── Alert builder ──────────────────────────────────────────────────────────────

function buildAlerts(
    dailyForecasts: DailyForecast[],
    events: ForecastEvent[],
    currentBalance: number,
    spendingInsight?: SpendingInsight,
): ForecastAlert[] {
    const alerts: ForecastAlert[] = [];

    for (const day of dailyForecasts) {
        // NEGATIVE_BALANCE
        if (day.closingBalanceSafe < 0) {
            alerts.push({
                type: 'NEGATIVE_BALANCE',
                date: day.date,
                message: `Your balance may go negative on ${day.date}`,
                severity: 'HIGH',
                amount: Math.abs(day.closingBalanceSafe),
            });
        }

        // INCOMING_DEPENDENCY
        if (day.closingBalanceSafe < 0 && day.closingBalanceExpected > 0) {
            const totalExpected = day.inflows
                .filter(e => e.certainty === 'EXPECTED')
                .reduce((s, e) => s + e.amount, 0);
            alerts.push({
                type: 'INCOMING_DEPENDENCY',
                date: day.date,
                message: `You are safe on ${day.date} only if you receive ${totalExpected.toLocaleString()} VND`,
                severity: 'HIGH',
                amount: totalExpected,
            });
        }

        // SUBSCRIPTION_AT_RISK
        const confirmedOut = day.outflows
            .filter(e => e.certainty === 'CONFIRMED')
            .reduce((s, e) => s + e.amount, 0);
        if (currentBalance > 0 && confirmedOut > currentBalance * 0.8) {
            alerts.push({
                type: 'SUBSCRIPTION_AT_RISK',
                date: day.date,
                message: `Subscription charges on ${day.date} exceed 80% of your current balance`,
                severity: 'MEDIUM',
                amount: confirmedOut,
            });
        }
    }

    // CLUSTERED_OUTFLOW: ≥ 3 outflow events in any 2 consecutive days
    for (let i = 0; i < dailyForecasts.length - 1; i++) {
        const total =
            dailyForecasts[i].outflows.length + dailyForecasts[i + 1].outflows.length;
        if (total >= 3) {
            alerts.push({
                type: 'CLUSTERED_OUTFLOW',
                date: dailyForecasts[i].date,
                message: `${total} outgoing payments are clustered around ${dailyForecasts[i].date}`,
                severity: 'MEDIUM',
            });
        }
    }

    // HIGH_RETRY_MEMBER
    const highRetry = events.filter(
        e => e.sourceType === 'SUBSCRIPTION' && (e.retryCount ?? 0) >= 2,
    );
    for (const e of highRetry) {
        alerts.push({
            type: 'HIGH_RETRY_MEMBER',
            message: `Subscription "${e.title}" has failed to charge ${e.retryCount} time(s). Ensure your balance is sufficient.`,
            severity: 'LOW',
            relatedEventIds: [e.id],
        });
    }

    // SPENDING_SPIKE: spending increased > 50% vs previous period
    if (spendingInsight && spendingInsight.changePercent > 50) {
        alerts.push({
            type: 'SPENDING_SPIKE',
            message: `Your spending increased by ${Math.round(spendingInsight.changePercent)}% compared to the previous period`,
            severity: 'MEDIUM',
            amount: spendingInsight.currentPeriodOutflow,
        });
    }

    return alerts;
}

// ── Spending Insight builder ───────────────────────────────────────────────────

async function buildSpendingInsights(
    userId: string,
    periodDays: number,
): Promise<SpendingInsight> {
    const now = new Date();
    const currentStart = addDays(now, -periodDays);
    const previousStart = addDays(now, -periodDays * 2);

    // Fetch transactions for both periods
    const txns = await Transaction.find({
        userId,
        createdAt: { $gte: previousStart },
    }).lean();

    let currentOutflow = 0;
    let previousOutflow = 0;
    const categoryMap = new Map<string, { amount: number; count: number }>();
    const dayOfWeekTotals = new Array(7).fill(0); // Sun=0 .. Sat=6
    let subscriptionTotal = 0;

    for (const tx of txns) {
        const type = (tx as any).type as string;
        if (!OUTFLOW_TYPES.has(type)) continue;

        const amount = Number((tx as any).amount ?? 0);
        const createdAt = new Date((tx as any).createdAt);

        if (createdAt >= currentStart) {
            // Current period
            currentOutflow += amount;

            // Category breakdown (current period only)
            const cat = categoryMap.get(type) ?? { amount: 0, count: 0 };
            cat.amount += amount;
            cat.count += 1;
            categoryMap.set(type, cat);

            // Day-of-week (current period)
            dayOfWeekTotals[createdAt.getDay()] += amount;

            if (type === 'SUBSCRIPTION_FEE') {
                subscriptionTotal += amount;
            }
        } else if (createdAt >= previousStart) {
            // Previous period
            previousOutflow += amount;
        }
    }

    // Build category breakdown sorted by amount desc
    const totalCurrent = currentOutflow || 1; // avoid div-by-zero
    const categoryBreakdown: CategoryBreakdown[] = Array.from(categoryMap.entries())
        .map(([category, { amount, count }]) => ({
            category,
            label: CATEGORY_LABELS[category] ?? category,
            amount,
            percent: Math.round((amount / totalCurrent) * 100),
            count,
        }))
        .sort((a, b) => b.amount - a.amount);

    // Trend
    let changePercent = 0;
    if (previousOutflow > 0) {
        changePercent = ((currentOutflow - previousOutflow) / previousOutflow) * 100;
    }
    const trend: 'UP' | 'DOWN' | 'STABLE' =
        changePercent > 10 ? 'UP' : changePercent < -10 ? 'DOWN' : 'STABLE';

    // Peak spending day
    const maxDayAmount = Math.max(...dayOfWeekTotals);
    const peakDayIndex = maxDayAmount > 0 ? dayOfWeekTotals.indexOf(maxDayAmount) : -1;
    const peakSpendingDay = peakDayIndex >= 0 ? DAY_NAMES[peakDayIndex] : null;

    // Subscription monthly estimate (extrapolate from period)
    const subscriptionMonthlyTotal = periodDays > 0
        ? Math.round((subscriptionTotal / periodDays) * 30)
        : 0;
    const subscriptionPercent = currentOutflow > 0
        ? Math.round((subscriptionTotal / currentOutflow) * 100)
        : 0;

    return {
        periodDays,
        currentPeriodOutflow: Math.round(currentOutflow * 100) / 100,
        previousPeriodOutflow: Math.round(previousOutflow * 100) / 100,
        changePercent: Math.round(changePercent * 10) / 10,
        trend,
        categoryBreakdown,
        dailyAvgSpending: Math.round((currentOutflow / periodDays) * 100) / 100,
        peakSpendingDay,
        subscriptionMonthlyTotal,
        subscriptionPercent,
    };
}

// ── Smart Tips generator ───────────────────────────────────────────────────────

function generateSmartTips(
    summary: Omit<ForecastSummary, 'healthScore' | 'healthLabel'>,
    spendingInsight: SpendingInsight,
    dailyForecasts: DailyForecast[],
): SmartTip[] {
    const tips: SmartTip[] = [];
    let id = 0;

    // 1. Spending trend
    if (spendingInsight.trend === 'UP' && spendingInsight.changePercent > 20) {
        tips.push({
            id: `tip_${++id}`,
            icon: '📈',
            title: 'Spending is rising',
            description: `Your spending increased by ${Math.round(spendingInsight.changePercent)}% compared to the previous period. Consider reviewing recent expenses.`,
            type: 'WARNING',
            priority: 2,
        });
    } else if (spendingInsight.trend === 'DOWN') {
        tips.push({
            id: `tip_${++id}`,
            icon: '📉',
            title: 'Great saving trend',
            description: `Your spending decreased by ${Math.abs(Math.round(spendingInsight.changePercent))}% — keep it up!`,
            type: 'INFO',
            priority: 5,
        });
    }

    // 2. Subscription burden
    if (spendingInsight.subscriptionPercent > 50) {
        tips.push({
            id: `tip_${++id}`,
            icon: '🔄',
            title: 'High subscription burden',
            description: `Subscriptions account for ${spendingInsight.subscriptionPercent}% of your spending. Review active subscriptions to optimize costs.`,
            type: 'SAVING',
            priority: 2,
        });
    } else if (spendingInsight.subscriptionPercent > 30) {
        tips.push({
            id: `tip_${++id}`,
            icon: '🔄',
            title: 'Subscription update',
            description: `Subscriptions make up ${spendingInsight.subscriptionPercent}% of your spending (est. ${spendingInsight.subscriptionMonthlyTotal.toLocaleString()} đ/month).`,
            type: 'INFO',
            priority: 4,
        });
    }

    // 3. Negative balance warning with action
    if (summary.firstNegativeDate) {
        const deficit = Math.abs(summary.minimumSafeBalance);
        tips.push({
            id: `tip_${++id}`,
            icon: '🔴',
            title: 'Top-up recommended',
            description: `You need at least ${deficit.toLocaleString()} đ before ${summary.firstNegativeDate} to avoid a negative balance.`,
            type: 'ACTION',
            priority: 1,
        });
    }

    // 4. Peak spending day
    if (spendingInsight.peakSpendingDay) {
        tips.push({
            id: `tip_${++id}`,
            icon: '📊',
            title: 'Peak spending day',
            description: `You tend to spend the most on ${spendingInsight.peakSpendingDay}s. Plan ahead to manage your budget.`,
            type: 'INFO',
            priority: 6,
        });
    }

    // 5. Expected inflow
    if (summary.totalExpectedInflow > 0) {
        tips.push({
            id: `tip_${++id}`,
            icon: '💰',
            title: 'Incoming payments',
            description: `You have ${summary.totalExpectedInflow.toLocaleString()} đ in expected incoming payments. Follow up to ensure timely receipt.`,
            type: 'INFO',
            priority: 4,
        });
    }

    // 6. All clear
    if (summary.firstNegativeDate === null && summary.alerts.length === 0) {
        tips.push({
            id: `tip_${++id}`,
            icon: '🎉',
            title: 'Looking good!',
            description: `Your finances are stable for the next ${summary.horizonDays} days. No action needed.`,
            type: 'INFO',
            priority: 7,
        });
    }

    // 7. Clustered outflow
    const hasClustered = summary.alerts.some(a => a.type === 'CLUSTERED_OUTFLOW');
    if (hasClustered) {
        tips.push({
            id: `tip_${++id}`,
            icon: '⏰',
            title: 'Payments bunched together',
            description: `Multiple payments are due around the same time. Consider spacing them out if possible.`,
            type: 'SAVING',
            priority: 3,
        });
    }

    // 8. Daily average insight
    if (spendingInsight.dailyAvgSpending > 0) {
        tips.push({
            id: `tip_${++id}`,
            icon: '📋',
            title: 'Daily spending average',
            description: `You spend an average of ${Math.round(spendingInsight.dailyAvgSpending).toLocaleString()} đ per day over the last ${spendingInsight.periodDays} days.`,
            type: 'INFO',
            priority: 7,
        });
    }

    // Sort by priority (lowest number = highest priority)
    return tips.sort((a, b) => a.priority - b.priority);
}

// ── Health Score calculator ────────────────────────────────────────────────────

function calculateHealthScore(
    dailyForecasts: DailyForecast[],
    alerts: ForecastAlert[],
    spendingInsight: SpendingInsight,
): { healthScore: number; healthLabel: string } {
    let score = 0;

    // Factor 1: No negative balance days (max 30 pts)
    const totalDays = dailyForecasts.length || 1;
    const safeDays = dailyForecasts.filter(d => d.closingBalanceSafe >= 0).length;
    score += Math.round((safeDays / totalDays) * 30);

    // Factor 2: Spending trend (max 20 pts)
    if (spendingInsight.trend === 'DOWN') {
        score += 20;
    } else if (spendingInsight.trend === 'STABLE') {
        score += 15;
    } else {
        // UP
        score += Math.max(0, 15 - Math.floor(spendingInsight.changePercent / 10));
    }

    // Factor 3: No HIGH alerts (max 20 pts)
    const highAlertCount = alerts.filter(a => a.severity === 'HIGH').length;
    score += Math.max(0, 20 - highAlertCount * 5);

    // Factor 4: Low subscription burden (max 15 pts)
    if (spendingInsight.subscriptionPercent < 30) {
        score += 15;
    } else if (spendingInsight.subscriptionPercent < 50) {
        score += 10;
    } else {
        score += 5;
    }

    // Factor 5: Has expected inflow (max 15 pts)
    const hasInflow = dailyForecasts.some(d => d.inflows.length > 0);
    score += hasInflow ? 15 : 10;

    // Clamp to 0–100
    score = Math.min(100, Math.max(0, score));

    // Label
    let healthLabel: string;
    if (score >= 85) healthLabel = 'Excellent';
    else if (score >= 70) healthLabel = 'Good';
    else if (score >= 50) healthLabel = 'Fair';
    else if (score >= 30) healthLabel = 'At Risk';
    else healthLabel = 'Critical';

    return { healthScore: score, healthLabel };
}

// ── Public API ─────────────────────────────────────────────────────────────────

export const forecastService = {
    async getForecast(
        userId: string,
        horizonDays = 30,
        spendingDays = 7,
    ): Promise<ForecastResponse> {
        const user = await User.findById(userId).select('balance currency').lean();
        const currentBalance = Number((user as any)?.balance ?? 0);

        // Run in parallel: forecast events + spending insights
        const [events, spendingInsight] = await Promise.all([
            buildForecastEvents(userId, horizonDays),
            buildSpendingInsights(userId, spendingDays),
        ]);

        const dailyForecasts = simulateBalance(currentBalance, events, horizonDays);
        const alerts = buildAlerts(dailyForecasts, events, currentBalance, spendingInsight);

        // Derive core summary fields
        let firstNegativeDate: string | null = null;
        let minimumSafeBalance = currentBalance;
        let minimumExpectedBalance = currentBalance;
        let totalConfirmedOutflow = 0;
        let totalExpectedInflow = 0;

        for (const day of dailyForecasts) {
            if (day.closingBalanceSafe < 0 && firstNegativeDate === null) {
                firstNegativeDate = day.date;
            }
            if (day.closingBalanceSafe < minimumSafeBalance) {
                minimumSafeBalance = day.closingBalanceSafe;
            }
            if (day.closingBalanceExpected < minimumExpectedBalance) {
                minimumExpectedBalance = day.closingBalanceExpected;
            }
        }

        events.forEach(e => {
            if (e.direction === 'OUTFLOW' && (e.certainty === 'CONFIRMED' || e.certainty === 'COMMITTED')) {
                totalConfirmedOutflow += e.amount;
            }
            if (e.direction === 'INFLOW' && e.certainty === 'EXPECTED') {
                totalExpectedInflow += e.amount;
            }
        });

        // Build preliminary summary (without healthScore) for tip generation
        const baseSummary = {
            currentBalance,
            horizonDays,
            firstNegativeDate,
            minimumSafeBalance,
            minimumExpectedBalance,
            totalConfirmedOutflow,
            totalExpectedInflow,
            alerts,
        };

        const smartTips = generateSmartTips(baseSummary, spendingInsight, dailyForecasts);
        const { healthScore, healthLabel } = calculateHealthScore(dailyForecasts, alerts, spendingInsight);

        const summary: ForecastSummary = {
            ...baseSummary,
            healthScore,
            healthLabel,
        };

        return { summary, dailyForecasts, events, spendingInsight, smartTips };
    },

    async getDashboardSummary(userId: string): Promise<ForecastSummary> {
        const { summary } = await forecastService.getForecast(userId, 7, 7);
        return summary;
    },
};
