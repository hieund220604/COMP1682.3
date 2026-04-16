import { Types } from 'mongoose';
import { Receipt, IReceipt } from '../models/Receipt';
import { ReceiptTag, IReceiptTag } from '../models/ReceiptTag';
import { ReceiptInput, ReceiptUpdateInput, ReceiptDto, TagDto, MonthSummaryItem, DayReceiptsResponse } from '../type/receipt';

class AppError extends Error {
    code?: string;
    status?: number;
    details?: any;
    constructor(message: string, code?: string, status?: number, details?: any) {
        super(message);
        this.code = code;
        this.status = status;
        this.details = details;
    }
}

const MAX_TAGS_PER_USER = 20;
const MAX_RECEIPTS_PER_DAY = 50;
const TAG_COLORS = ['#4F46E5', '#0EA5E9', '#22C55E', '#F59E0B', '#EF4444', '#EC4899', '#10B981', '#6366F1'];

function normalizeDate(dateStr?: string): Date {
    const d = dateStr ? new Date(dateStr) : new Date();
    if (isNaN(d.getTime())) {
        throw new AppError('Invalid receiptDate', 'INVALID_DATE');
    }
    d.setUTCHours(0, 0, 0, 0);
    return d;
}

function toTagDto(tag: IReceiptTag): TagDto {
    return {
        id: tag._id.toString(),
        name: tag.name,
        color: tag.color,
    };
}

function toReceiptDto(receipt: IReceipt, tags: IReceiptTag[]): ReceiptDto {
    const tagMap = new Map(tags.map(t => [t._id.toString(), t]));
    return {
        id: receipt._id.toString(),
        imageUrl: receipt.imageUrl,
        totalAmount: receipt.totalAmount || 0,
        note: receipt.note ?? null,
        receiptDate: receipt.receiptDate.toISOString().substring(0, 10),
        createdAt: receipt.createdAt.toISOString(),
        updatedAt: receipt.updatedAt.toISOString(),
        tags: receipt.tags
            .map(t => tagMap.get(t.toString()))
            .filter((t): t is IReceiptTag => !!t)
            .map(toTagDto),
    };
}

async function ensureUserHasTags(userId: string): Promise<void> {
    const count = await ReceiptTag.countDocuments({ userId });
    if (count === 0) {
        throw new AppError('User has no tags. Please create a tag first.', 'NO_TAGS_DEFINED', 400);
    }
}

async function ensureTagsOwned(tagIds: string[], userId: string): Promise<IReceiptTag[]> {
    if (!tagIds || tagIds.length === 0) {
        throw new AppError('At least one tag is required', 'TAGS_REQUIRED', 400);
    }
    const objectIds = tagIds.map(id => new Types.ObjectId(id));
    const tags = await ReceiptTag.find({ _id: { $in: objectIds }, userId });
    if (tags.length !== tagIds.length) {
        throw new AppError('One or more tags not found for this user', 'TAG_NOT_FOUND', 400);
    }
    return tags;
}

async function enforcePerDayLimit(userId: string, receiptDate: Date): Promise<void> {
    const count = await Receipt.countDocuments({ userId, receiptDate });
    if (count >= MAX_RECEIPTS_PER_DAY) {
        throw new AppError('Daily receipt limit reached', 'DAILY_LIMIT_EXCEEDED', 429);
    }
}

export const receiptService = {
    TAG_COLORS,

    async listTags(userId: string): Promise<TagDto[]> {
        const tags = await ReceiptTag.find({ userId }).sort({ createdAt: 1 });
        return tags.map(toTagDto);
    },

    async createTag(userId: string, name: string, color: string): Promise<TagDto> {
        if (!name || !name.trim()) {
            throw new AppError('Tag name is required', 'VALIDATION_ERROR');
        }
        if (name.length > 30) {
            throw new AppError('Tag name too long (max 30)', 'VALIDATION_ERROR');
        }
        if (!TAG_COLORS.includes(color)) {
            throw new AppError('Invalid tag color', 'INVALID_COLOR');
        }

        const tagCount = await ReceiptTag.countDocuments({ userId });
        if (tagCount >= MAX_TAGS_PER_USER) {
            throw new AppError('Tag limit reached', 'TAG_LIMIT_EXCEEDED');
        }

        const tag = await ReceiptTag.create({
            userId,
            name: name.trim().toLowerCase(),
            color,
        });
        return toTagDto(tag);
    },

    async updateTag(userId: string, tagId: string, name?: string, color?: string): Promise<TagDto> {
        const update: Partial<IReceiptTag> = {} as any;
        if (name !== undefined) {
            if (!name.trim()) throw new AppError('Tag name is required', 'VALIDATION_ERROR');
            if (name.length > 30) throw new AppError('Tag name too long (max 30)', 'VALIDATION_ERROR');
            update.name = name.trim().toLowerCase();
        }
        if (color !== undefined) {
            if (!TAG_COLORS.includes(color)) throw new AppError('Invalid tag color', 'INVALID_COLOR');
            update.color = color;
        }

        const tag = await ReceiptTag.findOneAndUpdate(
            { _id: tagId, userId },
            { $set: update },
            { new: true }
        );
        if (!tag) throw new AppError('Tag not found', 'NOT_FOUND', 404);
        return toTagDto(tag);
    },

    async deleteTag(userId: string, tagId: string): Promise<void> {
        // Prevent delete if in use
        const inUse = await Receipt.exists({ userId, tags: tagId });
        if (inUse) {
            throw new AppError('Tag is in use by receipts', 'TAG_IN_USE');
        }
        const result = await ReceiptTag.deleteOne({ _id: tagId, userId });
        if (result.deletedCount === 0) {
            throw new AppError('Tag not found', 'NOT_FOUND', 404);
        }
    },

    async createReceipt(userId: string, payload: ReceiptInput): Promise<ReceiptDto> {
        await ensureUserHasTags(userId);

        const receiptDate = normalizeDate(payload.receiptDate);
        await enforcePerDayLimit(userId, receiptDate);
        const tags = await ensureTagsOwned(payload.tagIds, userId);

        if (!payload.imageUrl || !payload.imageUrl.trim()) {
            throw new AppError('imageUrl is required', 'VALIDATION_ERROR');
        }
        if (payload.note && payload.note.length > 500) {
            throw new AppError('Note too long (max 500)', 'VALIDATION_ERROR');
        }

        const receipt = await Receipt.create({
            userId,
            imageUrl: payload.imageUrl.trim(),
            totalAmount: payload.totalAmount || 0,
            note: payload.note?.trim() || undefined,
            tags: tags.map(t => t._id),
            receiptDate,
        });

        return toReceiptDto(receipt, tags);
    },

    async getMonthSummary(userId: string, month: string): Promise<MonthSummaryItem[]> {
        // month format YYYY-MM
        if (!/^\d{4}-\d{2}$/.test(month)) {
            throw new AppError('Invalid month format. Use YYYY-MM', 'INVALID_MONTH');
        }
        const [year, m] = month.split('-').map(Number);
        const start = new Date(Date.UTC(year, m - 1, 1, 0, 0, 0, 0));
        const end = new Date(Date.UTC(year, m, 1, 0, 0, 0, 0));

        const agg = await Receipt.aggregate([
            { $match: { userId, receiptDate: { $gte: start, $lt: end } } },
            { $sort: { createdAt: 1 } },
            {
                $group: {
                    _id: '$receiptDate',
                    count: { $sum: 1 },
                    totalAmount: { $sum: { $ifNull: ['$totalAmount', 0] } },
                    thumbUrls: { $push: '$imageUrl' },
                }
            },
            { $project: { _id: 0, date: { $dateToString: { format: '%Y-%m-%d', date: '$_id' } }, count: 1, totalAmount: 1, thumbUrls: { $slice: ['$thumbUrls', 3] } } },
            { $sort: { date: 1 } }
        ]);

        return agg as MonthSummaryItem[];
    },

    async getDayReceipts(userId: string, dateStr: string): Promise<DayReceiptsResponse> {
        const date = normalizeDate(dateStr);
        const next = new Date(date);
        next.setUTCDate(date.getUTCDate() + 1);

        const receipts = await Receipt.find({ userId, receiptDate: { $gte: date, $lt: next } }).sort({ createdAt: 1 });
        const tagIds = receipts.flatMap(r => r.tags.map(t => t.toString()));
        const uniqueTagIds = Array.from(new Set(tagIds));
        const tags = await ReceiptTag.find({ _id: { $in: uniqueTagIds }, userId });

        return {
            date: date.toISOString().substring(0, 10),
            receipts: receipts.map(r => toReceiptDto(r, tags))
        };
    },

    async updateReceipt(userId: string, id: string, payload: ReceiptUpdateInput): Promise<ReceiptDto> {
        const receipt = await Receipt.findOne({ _id: id, userId });
        if (!receipt) throw new AppError('Receipt not found', 'NOT_FOUND', 404);

        if (payload.note !== undefined) {
            if (payload.note.length > 500) throw new AppError('Note too long (max 500)', 'VALIDATION_ERROR');
            receipt.note = payload.note.trim();
        }

        if (payload.totalAmount !== undefined) {
            receipt.totalAmount = payload.totalAmount;
        }

        let tags: IReceiptTag[] | null = null;
        if (payload.tagIds !== undefined) {
            tags = await ensureTagsOwned(payload.tagIds, userId);
            receipt.tags = tags.map(t => t._id);
        }

        await receipt.save();
        const allTags = tags ?? await ReceiptTag.find({ _id: { $in: receipt.tags }, userId });
        return toReceiptDto(receipt, allTags);
    },

    async deleteReceipt(userId: string, id: string): Promise<void> {
        const result = await Receipt.deleteOne({ _id: id, userId });
        if (result.deletedCount === 0) {
            throw new AppError('Receipt not found', 'NOT_FOUND', 404);
        }
    },
};

export { AppError };
