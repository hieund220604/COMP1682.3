// Subscription Types — v2

export enum BillingCycle {
    DAILY = 'DAILY',
    WEEKLY = 'WEEKLY',
    MONTHLY = 'MONTHLY',
    YEARLY = 'YEARLY'
}

export enum SubscriptionStatus {
    ACTIVE = 'ACTIVE',
    CANCELLED = 'CANCELLED'
}

// ── Request shapes ─────────────────────────────────────────────────────

export interface CreateSubscriptionRequest {
    groupId: string;
    name: string;
    description?: string;
    /** Fixed fee per member per cycle (VND). Not a total to split. */
    amount: number;
    billingCycle: BillingCycle;
}

export interface InviteMemberRequest {
    inviteeId: string;
}

export interface RespondInvitationRequest {
    invitationId: string;
    accept: boolean;
    categoryTagId?: string;
}

// ── Response shapes ────────────────────────────────────────────────────

export interface SubInvitationResponse {
    id: string;
    subscriptionId: string;
    inviteeId: string;
    invitedBy: string;
    status: string;
    expiresAt: Date;
    createdAt: Date;
    invitee?: {
        id: string;
        email: string;
        displayName?: string;
        avatarUrl?: string;
    };
}

export interface SubscriptionMemberResponse {
    id: string;
    userId: string;
    /** Amount this member pays per cycle (frozen at join time) */
    amount: number;
    status: string;
    joinedAt: Date;
    nextBillingDate: Date;
    lastChargedAt: Date;
    retryCount: number;
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
    groupName?: string;
    name: string;
    description?: string;
    /** Fixed fee per member per cycle */
    amount: number;
    currency: string;
    billingCycle: BillingCycle;
    /** ACTIVE = owner hasn't cancelled. CANCELLED = owner closed it. */
    status: SubscriptionStatus;
    createdBy: string;
    createdByName?: string;
    createdAt: Date;
    cancelledAt?: Date;
    members: SubscriptionMemberResponse[];
    memberCount: number;
    pendingInvitations?: SubInvitationResponse[];
}

// ── Scheduler result shapes ────────────────────────────────────────────

export interface MemberChargeResult {
    memberId: string;
    userId: string;
    subscriptionId: string;
    subscriptionName: string;
    amount: number;
    success: boolean;
    kicked: boolean;
    reason?: string;
}

export interface ProcessChargesResponse {
    processedAt: Date;
    totalMembersChecked: number;
    charged: number;
    failed: number;
    kicked: number;
    results: MemberChargeResult[];
}
