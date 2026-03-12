import { TransferStatus } from '../models/Transfer';
import { UserSummary } from './invoice';

// Request types
export interface InitiatePaymentRequest {
    // No body needed - initiates OTP for this transfer
}

export interface VerifyOTPRequest {
    otp: string;
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

    // Debt allocation details
    debtAllocations?: DebtAllocationDetail[];
}

export interface DebtAllocationDetail {
    originalDebtId: string;
    invoiceId: string;
    invoiceTitle: string;
    allocatedAmount: number;
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
