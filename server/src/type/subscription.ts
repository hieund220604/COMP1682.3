// Subscription Types

export enum BillingCycle {
    DAILY = 'DAILY',
    WEEKLY = 'WEEKLY',
    MONTHLY = 'MONTHLY',
    YEARLY = 'YEARLY'
}

export enum SubscriptionStatus {
    ACTIVE = 'ACTIVE',
    PAUSED = 'PAUSED',
    CANCELLED = 'CANCELLED',
    EXPIRED = 'EXPIRED',
    PAST_DUE = 'PAST_DUE'
}

export interface CreateSubscriptionRequest {
    groupId: string;
    name: string;
    description?: string;
    amount: number;          // Total amount to be split equally
    billingCycle: BillingCycle;
    startDate?: Date;        // Optional, defaults to now
}

export interface UpdateSubscriptionRequest {
    name?: string;
    description?: string;
    amount?: number;
    billingCycle?: BillingCycle;
}

export interface SubscriptionMemberResponse {
    id: string;
    userId: string;
    shareAmount: number;      // Amount this member pays per cycle
    status: string;
    joinedAt: Date;
    leftAt?: Date;
    user?: {
        id: string;
        email: string;
        displayName?: string;
        avatarUrl?: string;
    };
}

export interface SubscriptionResponse {
    id: string;
    groupId: string;
    groupName?: string;          // Group name instead of just ID
    name: string;
    description?: string;
    amount: number;           // Total amount
    currency: string;
    billingCycle: BillingCycle;
    status: SubscriptionStatus;
    nextBillingDate: Date;
    lastBilledAt?: Date;
    createdBy: string;
    createdByName?: string;      // Creator name instead of just ID
    createdAt: Date;
    cancelledAt?: Date;
    members: SubscriptionMemberResponse[];
    memberCount: number;
}

export interface ChargeResult {
    subscriptionId: string;
    subscriptionName: string;
    success: boolean;
    totalCharged: number;
    membersCharged: number;
    membersFailed: number;
    failedMembers: {
        userId: string;
        reason: string;
    }[];
    autoCancelled: boolean;
}

export interface ProcessChargesResponse {
    processedAt: Date;
    totalSubscriptions: number;
    successfulCharges: number;
    failedCharges: number;
    results: ChargeResult[];
}
