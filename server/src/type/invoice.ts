import { InvoiceStatus } from '../models/Invoice';

export type SplitType = 'EQUAL' | 'PERCENTAGE' | 'CUSTOM' | 'WEIGHT';

/** Per-user split value.
 * PERCENTAGE: value = 0-100 (must sum to 100)
 * CUSTOM:     value = exact amount (must sum to item.amount)
 * WEIGHT:     value = positive share weight (proportional)
 */
export interface InvoiceItemSplit {
    userId: string;
    value: number;
}

// Request types
export interface CreateInvoiceRequest {
    title: string;
    currency?: string;       // Invoice currency (default: group baseCurrency)
    invoiceDate?: string;
    imageUrl?: string;
    note?: string;
    items: InvoiceItemInput[];
}

export interface InvoiceItemInput {
    name: string;
    amount: number;
    splitType?: SplitType;            // defaults to 'EQUAL'
    assignedTo: string[];             // List of userIds
    splits?: InvoiceItemSplit[];      // Required for PERCENTAGE | CUSTOM | WEIGHT
}

export interface UpdateInvoiceRequest {
    title?: string;
    invoiceDate?: string;
    imageUrl?: string;
    note?: string;
    items?: InvoiceItemInput[];
}

// Response types
export interface InvoiceItemResponse {
    id: string;
    name: string;
    amount: number;
    splitType: SplitType;
    assignedTo: UserSummary[];
    splits?: InvoiceItemSplit[];
}

export interface UserSummary {
    id: string;
    displayName: string | null;
    avatarUrl: string | null;
}

export interface InvoiceResponse {
    id: string;
    groupId: string;
    title: string;
    amountTotal: number;
    currency: string;
    convertedAmountTotal?: number;  // Amount in baseCurrency (only if foreign currency)
    exchangeRate?: number;          // Rate used for conversion
    baseCurrency?: string;          // Group baseCurrency
    uploadedBy: UserSummary;
    invoiceDate: Date;
    imageUrl?: string;
    note?: string;
    isLocked: boolean;
    paymentRequestId?: string;
    isAdjustment: boolean;
    originalInvoiceId?: string;
    status: InvoiceStatus;
    items: InvoiceItemResponse[];
    createdAt: Date;
    updatedAt: Date;
}

// Debt breakdown for a user
export interface UserDebtBreakdown {
    invoiceId: string;
    invoiceTitle: string;
    creditor: UserSummary;
    originalAmount: number;
    remainingAmount: number;
    // Exchange rate lock info (present when invoice used foreign currency)
    originalCurrency?: string;
    originalAmountInCurrency?: number;
    exchangeRateUsed?: number;
}

export interface NetBalanceResponse {
    userId: string;
    netBalance: number;  // Positive = owed to them, Negative = they owe
    breakdown: UserDebtBreakdown[];
}

export { InvoiceStatus };
