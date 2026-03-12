export enum TopUpStatus {
    PENDING = 'PENDING',
    COMPLETED = 'COMPLETED',
    FAILED = 'FAILED'
}

export interface CreateTopUpRequest {
    accountId: string;
    amount: number;
    returnUrl: string;
}

export interface TopUpResponse {
    id: string;
    accountId: string;
    amount: number;
    status: TopUpStatus;
    paymentUrl?: string;
    createdAt: Date;
}
