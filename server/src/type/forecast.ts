// server/src/type/forecast.ts

export type ForecastSourceType =
    | 'SUBSCRIPTION'
    | 'TRANSFER_OUT'
    | 'TRANSFER_IN';

export type ForecastDirection = 'INFLOW' | 'OUTFLOW';

export type ForecastCertainty =
    | 'CONFIRMED'   // SubscriptionMember ACTIVE, nextBillingDate in horizon
    | 'COMMITTED'   // Pending outgoing transfer
    | 'EXPECTED';   // Pending incoming transfer

export type ForecastActionType =
    | 'OPEN_SUBSCRIPTION'
    | 'OPEN_TRANSFER'
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
        | 'HIGH_RETRY_MEMBER';
    date?: string;
    message: string;
    severity: 'HIGH' | 'MEDIUM' | 'LOW';
    amount?: number;
    relatedEventIds?: string[];
}

export interface ForecastSummary {
    currentBalance: number;
    horizonDays: number;
    firstNegativeDate: string | null;
    minimumSafeBalance: number;
    minimumExpectedBalance: number;
    totalConfirmedOutflow: number;
    totalExpectedInflow: number;
    alerts: ForecastAlert[];
}

export interface ForecastResponse {
    summary: ForecastSummary;
    dailyForecasts: DailyForecast[];
    events: ForecastEvent[];
}
