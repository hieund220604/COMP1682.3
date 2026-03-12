export enum TransactionType {
    TOP_UP = 'TOP_UP',
    WITHDRAWAL = 'WITHDRAWAL',
    TRANSFER_SENT = 'TRANSFER_SENT',
    TRANSFER_RECEIVED = 'TRANSFER_RECEIVED',
    VNPAY_PAYMENT = 'VNPAY_PAYMENT',
    EXPENSE_PAYMENT = 'EXPENSE_PAYMENT',
    SUBSCRIPTION_FEE = 'SUBSCRIPTION_FEE',
    REFUND = 'REFUND',
    DEPOSIT = 'DEPOSIT',
    TRANSFER_REFUND_SENT = 'TRANSFER_REFUND_SENT',
    TRANSFER_REFUND_RECEIVED = 'TRANSFER_REFUND_RECEIVED'
}

export interface CreateTransactionRequest {
    userId: string;
    groupId?: string;
    type: TransactionType;
    amount: number;
    balanceBefore: number;
    balanceAfter: number;
    currency?: string;
    description?: string;
    referenceId?: string;
    referenceType?: string;
    metadata?: any;
}

export interface TransactionResponse {
    id: string;
    userId: string;
    groupId?: string;
    type: TransactionType;
    amount: number;
    balanceBefore: number;
    balanceAfter: number;
    currency: string;
    description?: string;
    referenceId?: string;
    referenceType?: string;
    createdAt: Date;
}

export interface TransactionListResponse {
    transactions: TransactionResponse[];
    total: number;
    page: number;
    limit: number;
}
