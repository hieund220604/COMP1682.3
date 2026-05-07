import { TransferStatus } from '../models/Transfer';
import { UserSummary } from './invoice';

// Request types
export interface InitiatePaymentRequest {
    // No body needed - initiates OTP for this transfer
}

export interface VerifyOTPRequest {
    otp: string;
    categoryTagId?: string;
}

// Response types
export interface TransferResponse {
    id: string;
    paymentRequestId: string;
    groupId: string;
    fromUser: UserSummary;
    toUser: UserSummary;
    amount: number;
    status: TransferStatus;
    paidAt?: Date;
    otpExpiresAt?: Date;
    createdAt: Date;
    categoryTagId?: string;

    // Debt allocation details
    debtAllocations?: DebtAllocationDetail[];

    // Full debt context between payer and receiver
    debtContext?: {
        youOwe: DebtContextEntry[];    // Debts: payer owes receiver
        theyOwe: DebtContextEntry[];   // Counter-debts: receiver owes payer
        totalYouOwe: number;
        totalTheyOwe: number;
    };
}

export interface DebtAllocationDetail {
    originalDebtId: string;
    invoiceId: string;
    invoiceTitle: string;
    allocatedAmount: number;
}

export interface DebtContextEntry {
    invoiceId: string;
    invoiceTitle: string;
    debtAmount: number;  // originalAmount of the debt
}

export interface InitiatePaymentResponse {
    transferId: string;
    message: string;
    otpExpiresAt: Date;
}

export interface PaymentCompleteResponse {
    success: boolean;
    message: string;
    transfer: TransferResponse;
    newBalance: number;
}

export interface MyTransfersResponse {
    pending: TransferResponse[];
    completed: TransferResponse[];
    pendingIncoming: TransferResponse[];
}

export { TransferStatus };
