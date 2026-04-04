import { Types } from 'mongoose';

export interface ReceiptInput {
    imageUrl: string;
    note?: string;
    tagIds: string[];
    receiptDate?: string; // ISO date string YYYY-MM-DD
}

export interface ReceiptUpdateInput {
    note?: string;
    tagIds?: string[];
}

export interface ReceiptDto {
    id: string;
    imageUrl: string;
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
    thumbUrls: string[];
}

export interface DayReceiptsResponse {
    date: string;
    receipts: ReceiptDto[];
}

export type ObjectIdLike = string | Types.ObjectId;
