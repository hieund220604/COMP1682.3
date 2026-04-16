export enum GroupRole {
    ADMIN = "ADMIN",
    OWNER = "OWNER",
    USER = "USER"
}

export interface CreateGroupRequest {
    name: string;
    description?: string;
    baseCurrency?: string;
}

export interface UpdateGroupRequest {
    name?: string;
    description?: string;
    baseCurrency?: string;
}

export interface GroupResponse {
    id: string;
    name: string;
    description: string;
    joinCode?: string;
    baseCurrency: string;
    createdAt: Date;
    createdBy: string;
    memberCount?: number;
    members?: GroupMemberResponse[];
}

export interface GroupMemberResponse {
    id: string;
    userId: string;
    groupId: string;
    role: GroupRole;
    joinedAt: Date;
    leftAt?: Date | null;
    user?: {
        id: string;
        email: string;
        displayName?: string;
        avatarUrl?: string;
    }
}

export interface InviteRequest {
    emailInvite: string;
    role: GroupRole;
}


export interface InviteResponse {
    id: string;
    emailInvite: string;
    role: GroupRole;
    status: "PENDING" | "ACCEPTED" | "EXPIRED";
    expiresAt: Date;
    createdAt: Date;
    token?: string;
    groupName?: string;
    groupId?: string;
    invitedByName?: string;
}

export interface AcceptInviteRequest {
    token: string;
}

export interface UpdateMemberRoleRequest {
    role: GroupRole;
}

export interface GroupBalanceResponse {
    groupId: string;
    members: {
        userId: string;
        displayName?: string;
        totalOwed: number;
        totalLent: number;
        netBalance: number;
    }[];
}

export interface PaginationMeta {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
}

export interface ApiResponse<T> {
    success: boolean;
    data?: T; //data will replace this, if success is true, T will be the type of data
    message?: string;
    error?: {
        message: string;
        code: string;
    };
    details?: any[];
    meta?: PaginationMeta;
}
