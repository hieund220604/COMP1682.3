export interface DebtEntry {
    userId: string;
    displayName?: string;
    avatarUrl?: string;
    amount: number;
    currency: string;
}

export interface UserDebtsResponse {
    groupId: string;
    currency: string;
    /** Debts where I owe money to others */
    iOwe: DebtEntry[];
    /** Debts where others owe money to me */
    oweMe: DebtEntry[];
    /** Net balance: positive = others owe me, negative = I owe others */
    netBalance: number;
}

export interface PayBalanceRequest {
    settlementId: string;
}

export interface PayBalanceResponse {
    success: boolean;
    message: string;
    settlementId: string;
    amountPaid: number;
    newBalance: number;
}
