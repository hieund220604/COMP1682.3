export enum SplitType {
    EQUAL = "EQUAL",
    EXACT = "EXACT",
    PERCENT = "PERCENT",
    ITEM_BASED = "ITEM_BASED"
}

export interface ExpenseShareInput {
    userId: string;
    amount?: number;
    percent?: number;
}

export interface ExpenseItemInput {
    name: string;
    price: number;
    quantity?: number;
    assignedTo: string;
}

export interface CreateExpenseRequest {
    title: string;
    amountTotal: number;
    currency?: string;
    category?: string;
    expenseType?: string;
    expenseDate?: Date;
    note?: string;
    splitType: SplitType;
    shares?: ExpenseShareInput[];
    items?: ExpenseItemInput[];
}

export interface UpdateExpenseRequest {
    title?: string;
    amountTotal?: number;
    currency?: string;
    category?: string;
    expenseType?: string;
    expenseDate?: Date;
    note?: string;
    splitType?: SplitType;
    shares?: ExpenseShareInput[];
}

export interface UserSummary {
    id: string;
    email: string;
    displayName?: string;
    avatarUrl?: string;
}

export interface ExpenseShareResponse {
    id: string;
    expenseId: string;
    userId: string;
    owedAmount: number;
    shareNote?: string;
    user?: UserSummary;
}

export interface ExpenseItemResponse {
    id: string;
    expenseId: string;
    name: string;
    price: number;
    quantity: number;
    assignedTo: string;
    user?: UserSummary;
}

export interface ExpenseResponse {
    id: string;
    groupId: string;
    title: string;
    amountTotal: number;
    currency: string;
    splitType: string;
    category?: string;
    expenseType?: string;
    paidBy: UserSummary;
    expenseDate: Date;
    note?: string;
    shares: ExpenseShareResponse[];
    items?: ExpenseItemResponse[];
    createdAt: Date;
}

export interface ExpenseListResponse {
    expenses: ExpenseResponse[];
    total: number;
}
