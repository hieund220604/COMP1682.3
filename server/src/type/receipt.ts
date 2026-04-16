import { Types } from 'mongoose';

export interface ReceiptInput {
    imageUrl: string;
    totalAmount?: number;
    note?: string;
    tagIds: string[];
    receiptDate?: string; // ISO date string YYYY-MM-DD
}

export interface ReceiptUpdateInput {
    totalAmount?: number;
    note?: string;
    tagIds?: string[];
}

export interface ReceiptDto {
    id: string;
    imageUrl: string;
    totalAmount: number;
    note?: string | null;
    tags: TagDto[];
    receiptDate: string; // ISO date (UTC)
    createdAt: string;
    updatedAt: string;
}

export interface TagDto {
    id: string;
    name: string;
    color: string;
}

export interface MonthSummaryItem {
    date: string; // YYYY-MM-DD
    count: number;
    totalAmount: number;
    thumbUrls: string[];
}

export interface DayReceiptsResponse {
    date: string;
    receipts: ReceiptDto[];
}

export type ObjectIdLike = string | Types.ObjectId;
