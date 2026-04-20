// server/src/service/forecastService.ts
import mongoose from 'mongoose';
import { User } from '../models/User';
import { SubscriptionMember } from '../models/SubscriptionMember';
import { Subscription } from '../models/Subscription';
import { Transfer } from '../models/Transfer';
import { PaymentRequest } from '../models/PaymentRequest';
import {
    ForecastEvent,
    DailyForecast,
    ForecastAlert,
    ForecastSummary,
    ForecastResponse,
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

    return alerts;
}

// ── Public API ─────────────────────────────────────────────────────────────────

export const forecastService = {
    async getForecast(userId: string, horizonDays = 30): Promise<ForecastResponse> {
        const user = await User.findById(userId).select('balance currency').lean();
        const currentBalance = Number((user as any)?.balance ?? 0);

        const events = await buildForecastEvents(userId, horizonDays);
        const dailyForecasts = simulateBalance(currentBalance, events, horizonDays);
        const alerts = buildAlerts(dailyForecasts, events, currentBalance);

        // Derive summary
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

        const summary: ForecastSummary = {
            currentBalance,
            horizonDays,
            firstNegativeDate,
            minimumSafeBalance,
            minimumExpectedBalance,
            totalConfirmedOutflow,
            totalExpectedInflow,
            alerts,
        };

        return { summary, dailyForecasts, events };
    },

    async getDashboardSummary(userId: string): Promise<ForecastSummary> {
        const { summary } = await forecastService.getForecast(userId, 7);
        return summary;
    },
};
