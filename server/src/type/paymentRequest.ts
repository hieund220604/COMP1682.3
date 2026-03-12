import { PaymentRequestStatus } from '../models/PaymentRequest';
import { UserSummary, UserDebtBreakdown } from './invoice';

// Request types
export interface CreatePaymentRequestRequest {
    // No body needed - system auto-collects submitted invoices
}

// Response types
export interface PaymentRequestResponse {
    id: string;
    groupId: string;
    createdBy: UserSummary;
    invoiceIds: string[];
    status: PaymentRequestStatus;
    issuedAt: Date;
    paidAt?: Date;
    cancelledAt?: Date;
    createdAt: Date;

    // Summary
    totalAmount: number;
    totalTransfers: number;
    completedTransfers: number;
}

export interface PaymentRequestDetailResponse extends PaymentRequestResponse {
    // Breakdown per user
    userBreakdowns: UserPaymentBreakdown[];
    // All transfers in this request
    transfers: TransferSummary[];
}

export interface UserPaymentBreakdown {
    user: UserSummary;
    netBalance: number;  // Negative = needs to pay, Positive = receives
    debts: UserDebtBreakdown[];
}

export interface TransferSummary {
    id: string;
    fromUser: UserSummary;
    toUser: UserSummary;
    amount: number;
    status: string;
    paidAt?: Date;
    // Currency conversion info
    originalCurrency?: string;
    originalAmount?: number;
    convertedCurrency?: string;
    exchangeRate?: number;
}

export { PaymentRequestStatus };
