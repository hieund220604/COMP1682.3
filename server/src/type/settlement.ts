export enum SettlementStatus {
    PENDING = "PENDING",
    COMPLETED = "COMPLETED",
    FAILED = "FAILED"
}

export interface CreateSettlementRequest {
    toUserId: string;
    amount: number;
    currency?: string;
    note?: string;
}

export interface UserSummary {
    id: string;
    email: string;
    displayName?: string;
    avatarUrl?: string;
}

export interface SettlementResponse {
    id: string;
    groupId: string;
    fromUser: UserSummary;
    toUser: UserSummary;
    amount: number;
    currency: string;
    status: SettlementStatus;
    settlementDate?: Date | null;
    note?: string;
    vnpayTxnRef?: string;
    createdAt: Date;
}

export interface SuggestedSettlement {
    fromUserId: string;
    fromUserName?: string;
    toUserId: string;
    toUserName?: string;
    amount: number;
    currency: string;
}
