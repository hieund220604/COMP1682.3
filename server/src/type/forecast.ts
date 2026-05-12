// server/src/type/forecast.ts

export type ForecastSourceType =
    | 'SUBSCRIPTION'
    | 'TRANSFER_OUT'
    | 'TRANSFER_IN'
    | 'RECEIPT_SPENDING';

export type ForecastDirection = 'INFLOW' | 'OUTFLOW';

export type ForecastCertainty =
    | 'CONFIRMED'   // SubscriptionMember ACTIVE, nextBillingDate in horizon
    | 'COMMITTED'   // Pending outgoing transfer
    | 'EXPECTED';   // Pending incoming transfer

export type ForecastActionType =
    | 'OPEN_SUBSCRIPTION'
    | 'OPEN_TRANSFER'
    | 'OPEN_RECEIPT'
    | 'TOP_UP';

export interface ForecastEvent {
    id: string;
    sourceType: ForecastSourceType;
    sourceId: string;
    direction: ForecastDirection;
    certainty: ForecastCertainty;
    amount: number;
    currency: string;
    effectiveDate: Date;
    title: string;
    counterparty?: string;
    groupName?: string;
    actionType: ForecastActionType;
    status: string;
    retryCount?: number; // for subscription members
    receiptTagName?: string; // for receipt spending events
}

export interface DailyForecast {
    date: string; // yyyy-MM-dd
    openingBalance: number;
    outflows: ForecastEvent[];
    inflows: ForecastEvent[];
    closingBalanceSafe: number;
    closingBalanceExpected: number;
}

export interface ForecastAlert {
    type:
        | 'NEGATIVE_BALANCE'
        | 'CLUSTERED_OUTFLOW'
        | 'SUBSCRIPTION_AT_RISK'
        | 'INCOMING_DEPENDENCY'
        | 'HIGH_RETRY_MEMBER'
        | 'SPENDING_SPIKE';
    date?: string;
    message: string;
    severity: 'HIGH' | 'MEDIUM' | 'LOW';
    amount?: number;
    relatedEventIds?: string[];
}

// ── Spending Insights ──────────────────────────────────────────────────────────

export interface CategoryBreakdown {
    category: string;
    label: string;       // human-friendly label
    amount: number;
    percent: number;
    count: number;
}

export interface SpendingInsight {
    periodDays: number;
    currentPeriodOutflow: number;
    previousPeriodOutflow: number;
    changePercent: number;
    trend: 'UP' | 'DOWN' | 'STABLE';
    categoryBreakdown: CategoryBreakdown[];
    dailyAvgSpending: number;
    peakSpendingDay: string | null;        // "Monday", "Friday" etc.
    subscriptionMonthlyTotal: number;
    subscriptionPercent: number;
}

// ── Smart Tips ─────────────────────────────────────────────────────────────────

export interface SmartTip {
    id: string;
    icon: string;
    title: string;
    description: string;
    type: 'SAVING' | 'WARNING' | 'INFO' | 'ACTION';
    priority: number;  // 1 = highest
}

// ── Summary ────────────────────────────────────────────────────────────────────

export interface ForecastSummary {
    currentBalance: number;
    horizonDays: number;
    firstNegativeDate: string | null;
    minimumSafeBalance: number;
    minimumExpectedBalance: number;
    totalConfirmedOutflow: number;
    totalExpectedInflow: number;
    alerts: ForecastAlert[];
    healthScore: number;       // 0–100
    healthLabel: string;       // 'Excellent' | 'Good' | 'Fair' | 'At Risk' | 'Critical'
}

// ── Response ───────────────────────────────────────────────────────────────────

export interface ForecastResponse {
    summary: ForecastSummary;
    dailyForecasts: DailyForecast[];
    events: ForecastEvent[];
    spendingInsight: SpendingInsight;
    smartTips: SmartTip[];
}
