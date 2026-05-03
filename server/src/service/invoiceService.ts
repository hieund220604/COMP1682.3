import { Invoice, InvoiceStatus } from '../models/Invoice';
import { InvoiceItem } from '../models/InvoiceItem';
import { GroupMember } from '../models/GroupMember';
import { Group } from '../models/Group';
import { User } from '../models/User';
import { OriginalDebt } from '../models/OriginalDebt';
import { notificationService } from './notificationService';
import { NotificationType } from '../models/Notification';
import { exchangeRateService } from './exchangeRateService';
import {
    CreateInvoiceRequest,
    UpdateInvoiceRequest,
    InvoiceResponse,
    InvoiceItemResponse,
    UserSummary,
    InvoiceItemInput,
    InvoiceItemSplit
} from '../type/invoice';
import mongoose from 'mongoose';
import { buildRedisKey, deleteKeysByPrefix, getJsonCache, setJsonCache } from '../redis';

const transformUser = (user: any): UserSummary => ({
    id: user._id.toString(),
    displayName: user.displayName,
    avatarUrl: user.avatarUrl
});

const INVOICE_DETAIL_CACHE_TTL_SECONDS = 60;
const INVOICE_LIST_CACHE_TTL_SECONDS = 45;

function invoiceDetailCacheKey(userId: string, groupId: string, invoiceId: string): string {
    return buildRedisKey('cache', 'invoice', groupId, 'detail', userId, invoiceId);
}

function invoiceListCacheKey(userId: string, groupId: string, status?: InvoiceStatus): string {
    return buildRedisKey('cache', 'invoice', groupId, 'list', userId, status || 'ALL');
}

async function invalidateInvoiceCache(groupId: string): Promise<void> {
    await deleteKeysByPrefix(buildRedisKey('cache', 'invoice', groupId));
}

/**
 * Validate that splits data is consistent with the chosen splitType.
 */
function validateItemSplits(item: InvoiceItemInput): void {
    const splitType = item.splitType || 'EQUAL';
    if (splitType === 'EQUAL') return;

    if (!item.splits || item.splits.length === 0) {
        throw new Error(`Item "${item.name}": splits are required for ${splitType} split type`);
    }

    for (const uid of item.assignedTo) {
        if (!item.splits.find(s => s.userId === uid)) {
            throw new Error(`Item "${item.name}": missing split value for user ${uid}`);
        }
    }

    if (splitType === 'PERCENTAGE') {
        const total = item.splits.reduce((s, x) => s + x.value, 0);
        if (Math.abs(total - 100) > 0.01) {
            throw new Error(`Item "${item.name}": percentages must sum to 100, got ${total.toFixed(2)}`);
        }
    }

    if (splitType === 'CUSTOM') {
        const total = item.splits.reduce((s, x) => s + x.value, 0);
        if (Math.abs(total - item.amount) > 0.01) {
            throw new Error(`Item "${item.name}": custom amounts must sum to ${item.amount}, got ${total.toFixed(2)}`);
        }
    }

    if (splitType === 'WEIGHT') {
        for (const split of item.splits) {
            if (split.value <= 0) {
                throw new Error(`Item "${item.name}": all share weights must be positive`);
            }
        }
    }
}

/**
 * Calculate how much a specific debtor owes for one invoice item.
 */
function calculateShareForUser(
    item: { amount: number; assignedTo: string[]; splitType?: string; splits?: InvoiceItemSplit[] },
    debtorId: string
): number {
    const splitType = item.splitType || 'EQUAL';

    switch (splitType) {
        case 'PERCENTAGE': {
            const split = item.splits?.find(s => s.userId === debtorId);
            if (!split) return 0;
            return Math.floor(item.amount * (split.value / 100));
        }
        case 'CUSTOM': {
            const split = item.splits?.find(s => s.userId === debtorId);
            if (!split) return 0;
            return split.value;
        }
        case 'WEIGHT': {
            const totalWeight = item.splits?.reduce((s, x) => s + x.value, 0) || 1;
            const split = item.splits?.find(s => s.userId === debtorId);
            if (!split) return 0;
            return Math.floor(item.amount * (split.value / totalWeight));
        }
        case 'EQUAL':
        default:
            return item.assignedTo.length > 0 ? Math.floor(item.amount / item.assignedTo.length) : 0;
    }
}

export const invoiceService = {
    /**
     * Create a new invoice with items
     */
    async createInvoice(userId: string, groupId: string, data: CreateInvoiceRequest): Promise<InvoiceResponse> {
        // Verify user is member of group
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }

        // Calculate total amount from items
        const amountTotal = data.items.reduce((sum, item) => sum + item.amount, 0);

        // Validate all assigned users are group members
        const allAssignedUsers = new Set<string>();
        data.items.forEach(item => item.assignedTo.forEach(uid => allAssignedUsers.add(uid)));

        for (const assignedUserId of allAssignedUsers) {
            const isMember = await GroupMember.findOne({ groupId, userId: assignedUserId, leftAt: null });
            if (!isMember) {
                throw new Error(`User ${assignedUserId} is not a member of this group`);
            }
        }

        // Validate invoice has at least one item
        if (data.items.length === 0) {
            throw new Error('Invoice must have at least one item');
        }

        // Validate splits for each item
        for (const item of data.items) {
            validateItemSplits(item);
        }

        const session = await mongoose.startSession();
        let invoice: any;
        let invoiceItems: any[] = [];

        try {
            await session.withTransaction(async () => {
                // Determine currency and exchange rate
                const group = await Group.findById(groupId).session(session);
                if (!group) throw new Error('Group not found');
                const baseCurrency = group.baseCurrency || 'VND';
                const invoiceCurrency = data.currency?.toUpperCase() || baseCurrency;
                const isForeignCurrency = invoiceCurrency !== baseCurrency;

                let exchangeRate: number | null = null;
                let convertedAmountTotal: number | null = null;

                if (isForeignCurrency) {
                    // Lock exchange rate at invoice creation time
                    exchangeRate = await exchangeRateService.getRate(invoiceCurrency, baseCurrency);
                    convertedAmountTotal = Math.round(amountTotal * exchangeRate * 100) / 100;
                }

                // Create invoice with SUBMITTED status
                [invoice] = await Invoice.create([{
                    groupId,
                    title: data.title,
                    amountTotal,
                    currency: invoiceCurrency,
                    convertedAmountTotal: isForeignCurrency ? convertedAmountTotal : null,
                    exchangeRate: isForeignCurrency ? Math.round(exchangeRate! * 10000) / 10000 : null,
                    baseCurrency: isForeignCurrency ? baseCurrency : null,
                    uploadedBy: userId,
                    invoiceDate: data.invoiceDate ? new Date(data.invoiceDate) : new Date(),
                    imageUrl: data.imageUrl,
                    note: data.note,
                    status: 'SUBMITTED'
                }], { session });

                // Create invoice items (amounts in original invoice currency)
                invoiceItems = await InvoiceItem.create(
                    data.items.map(item => ({
                        invoiceId: invoice._id.toString(),
                        name: item.name,
                        amount: item.amount,
                        splitType: item.splitType || 'EQUAL',
                        assignedTo: item.assignedTo,
                        splits: item.splits || []
                    })),
                    { session, ordered: true }
                );

                // Calculate debt per user using the appropriate split method
                const debtMap = new Map<string, number>();

                for (let i = 0; i < invoiceItems.length; i++) {
                    const dbItem = invoiceItems[i];
                    const inputItem = data.items[i];
                    if (dbItem.assignedTo.length === 0) continue;

                    for (const debtorId of dbItem.assignedTo) {
                        // Skip if debtor is the uploader (can't owe themselves)
                        if (debtorId === userId) continue;

                        const share = calculateShareForUser(
                            { amount: dbItem.amount, assignedTo: dbItem.assignedTo, splitType: dbItem.splitType, splits: inputItem.splits },
                            debtorId
                        );
                        debtMap.set(debtorId, (debtMap.get(debtorId) || 0) + share);
                    }
                }

                // Create original debts (amounts always in baseCurrency)
                const now = new Date();
                const debts = Array.from(debtMap.entries()).map(([debtorId, amountInCurrency]) => {
                    // amountInCurrency is already floored from calculateShareForUser
                    const amountInBase = isForeignCurrency
                        ? Math.floor(amountInCurrency * exchangeRate!)
                        : amountInCurrency;
                    const amountInCurrencyRounded = amountInCurrency;

                    return {
                        groupId,
                        invoiceId: invoice._id.toString(),
                        debtorId,
                        creditorId: userId,
                        originalAmount: amountInBase,
                        remainingAmount: amountInBase,
                        // Exchange rate lock (only for foreign currency)
                        ...(isForeignCurrency ? {
                            originalCurrency: invoiceCurrency,
                            originalAmountInCurrency: amountInCurrencyRounded,
                            exchangeRateUsed: Math.round(exchangeRate! * 10000) / 10000,
                            rateLockedAt: now
                        } : {})
                    };
                });

                if (debts.length > 0) {
                    await OriginalDebt.create(debts, { session, ordered: true });
                }
            });
        } finally {
            session.endSession();
        }

        // Send notifications to assigned users (after transaction completes)
        const uploader = await User.findById(userId);
        const uploaderName = uploader?.displayName || 'Someone';

        // Notify all assigned users about the new invoice
        for (const assignedUserId of allAssignedUsers) {
            if (assignedUserId !== userId) { // Don't notify the uploader
                await notificationService.createNotification({
                    userId: assignedUserId,
                    type: NotificationType.INVOICE_CREATED,
                    title: 'New Invoice',
                    message: `${uploaderName} added a new invoice: ${data.title}`,
                    data: {
                        invoiceId: invoice._id.toString(),
                        groupId,
                        title: data.title,
                        amount: amountTotal
                    }
                });
            }
        }

        await invalidateInvoiceCache(groupId);

        return this.getInvoiceById(userId, groupId, invoice._id.toString());
    },

    /**
     * Get invoice by ID
     */
    async getInvoiceById(userId: string, groupId: string, invoiceId: string): Promise<InvoiceResponse> {
        // Verify user is member
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }

        const cacheKey = invoiceDetailCacheKey(userId, groupId, invoiceId);
        const cached = await getJsonCache<InvoiceResponse>(cacheKey);
        if (cached) {
            return cached;
        }

        const invoice = await Invoice.findOne({ _id: invoiceId, groupId });
        if (!invoice) {
            throw new Error('Invoice not found');
        }

        const uploader = await User.findById(invoice.uploadedBy);
        const items = await InvoiceItem.find({ invoiceId });

        // Get assigned users for each item
        const itemResponses: InvoiceItemResponse[] = await Promise.all(
            items.map(async (item) => {
                const assignedUsers = await User.find({ _id: { $in: item.assignedTo } });
                return {
                    id: item._id.toString(),
                    name: item.name,
                    amount: item.amount,
                    splitType: item.splitType || 'EQUAL',
                    assignedTo: assignedUsers.map(transformUser),
                    splits: item.splits && item.splits.length > 0 ? item.splits.map(s => ({ userId: s.userId, value: s.value })) : undefined
                };
            })
        );

        const response: InvoiceResponse = {
            id: invoice._id.toString(),
            groupId: invoice.groupId,
            title: invoice.title,
            amountTotal: invoice.amountTotal,
            currency: invoice.currency,
            convertedAmountTotal: invoice.convertedAmountTotal ?? undefined,
            exchangeRate: invoice.exchangeRate ?? undefined,
            baseCurrency: invoice.baseCurrency ?? undefined,
            uploadedBy: uploader ? transformUser(uploader) : { id: invoice.uploadedBy, displayName: null, avatarUrl: null },
            invoiceDate: invoice.invoiceDate,
            imageUrl: invoice.imageUrl ?? undefined,
            note: invoice.note ?? undefined,
            isLocked: invoice.isLocked,
            paymentRequestId: invoice.paymentRequestId ?? undefined,
            isAdjustment: invoice.isAdjustment,
            originalInvoiceId: invoice.originalInvoiceId ?? undefined,
            status: invoice.status,
            items: itemResponses,
            createdAt: invoice.createdAt,
            updatedAt: invoice.updatedAt
        };

        await setJsonCache(cacheKey, response, INVOICE_DETAIL_CACHE_TTL_SECONDS);
        return response;
    },

    /**
     * Get all invoices in a group
     */
    async getInvoicesByGroup(userId: string, groupId: string, status?: InvoiceStatus): Promise<InvoiceResponse[]> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }

        const cacheKey = invoiceListCacheKey(userId, groupId, status);
        const cached = await getJsonCache<InvoiceResponse[]>(cacheKey);
        if (cached) {
            return cached;
        }

        const query: any = { groupId };
        if (status) {
            query.status = status;
        }

        const invoices = await Invoice.find(query).sort({ createdAt: -1 });

        const result = await Promise.all(
            invoices.map(inv => this.getInvoiceById(userId, groupId, inv._id.toString()))
        );

        await setJsonCache(cacheKey, result, INVOICE_LIST_CACHE_TTL_SECONDS);
        return result;
    },

    /**
     * Get unlocked invoices (for payment request creation)
     */
    async getUnlockedInvoices(groupId: string): Promise<InvoiceResponse[]> {
        const invoices = await Invoice.find({
            groupId,
            status: 'SUBMITTED',
            isLocked: false
        }).sort({ createdAt: -1 });

        // Return basic info without full population for efficiency
        const uploaderIds = [...new Set(invoices.map(i => i.uploadedBy))];
        const uploaders = await User.find({ _id: { $in: uploaderIds } });
        const uploaderMap = new Map(uploaders.map(u => [u._id.toString(), u]));

        return Promise.all(invoices.map(async (invoice) => {
            const uploader = uploaderMap.get(invoice.uploadedBy);
            const items = await InvoiceItem.find({ invoiceId: invoice._id.toString() });

            const itemResponses: InvoiceItemResponse[] = await Promise.all(
                items.map(async (item) => {
                    const assignedUsers = await User.find({ _id: { $in: item.assignedTo } });
                    return {
                        id: item._id.toString(),
                        name: item.name,
                        amount: item.amount,
                        splitType: item.splitType || 'EQUAL',
                        assignedTo: assignedUsers.map(transformUser),
                        splits: item.splits && item.splits.length > 0 ? item.splits.map(s => ({ userId: s.userId, value: s.value })) : undefined
                    };
                })
            );

            return {
                id: invoice._id.toString(),
                groupId: invoice.groupId,
                title: invoice.title,
                amountTotal: invoice.amountTotal,
                currency: invoice.currency,
                convertedAmountTotal: invoice.convertedAmountTotal ?? undefined,
                exchangeRate: invoice.exchangeRate ?? undefined,
                baseCurrency: invoice.baseCurrency ?? undefined,
                uploadedBy: uploader ? transformUser(uploader) : { id: invoice.uploadedBy, displayName: null, avatarUrl: null },
                invoiceDate: invoice.invoiceDate,
                imageUrl: invoice.imageUrl ?? undefined,
                note: invoice.note ?? undefined,
                isLocked: invoice.isLocked,
                paymentRequestId: invoice.paymentRequestId ?? undefined,
                isAdjustment: invoice.isAdjustment,
                originalInvoiceId: invoice.originalInvoiceId ?? undefined,
                status: invoice.status,
                items: itemResponses,
                createdAt: invoice.createdAt,
                updatedAt: invoice.updatedAt
            };
        }));
    },

    /**
     * Update invoice (only if not locked)
     */
    async updateInvoice(userId: string, groupId: string, invoiceId: string, data: UpdateInvoiceRequest): Promise<InvoiceResponse> {
        const invoice = await Invoice.findOne({ _id: invoiceId, groupId });
        if (!invoice) {
            throw new Error('Invoice not found');
        }

        // DRAFT invoices (from recurring templates) can be updated by any owner/admin of the group
        // SUBMITTED/LOCKED invoices can only be updated by the uploader
        if (invoice.status !== 'DRAFT') {
            if (invoice.uploadedBy !== userId) {
                throw new Error('Only the uploader can update this invoice');
            }
        }

        // Cannot update locked invoice
        if (invoice.isLocked) {
            throw new Error('Cannot update locked invoice');
        }

        const session = await mongoose.startSession();

        try {
            await session.withTransaction(async () => {
                // Update invoice fields
                if (data.title) invoice.title = data.title;
                if (data.invoiceDate) invoice.invoiceDate = new Date(data.invoiceDate);
                if (data.imageUrl !== undefined) invoice.imageUrl = data.imageUrl;
                if (data.note !== undefined) invoice.note = data.note;

                // Update items if provided
                if (data.items) {
                    // Validate splits for each incoming item
                    for (const item of data.items) {
                        validateItemSplits(item);
                    }

                    // Delete existing items and debts
                    await InvoiceItem.deleteMany({ invoiceId }, { session });
                    await OriginalDebt.deleteMany({ invoiceId }, { session });

                    // Calculate new total
                    const amountTotal = data.items.reduce((sum, item) => sum + item.amount, 0);
                    invoice.amountTotal = amountTotal;

                    // Re-calculate converted amount using the LOCKED rate (if foreign currency)
                    if (invoice.exchangeRate && invoice.baseCurrency) {
                        invoice.convertedAmountTotal = Math.round(amountTotal * invoice.exchangeRate * 100) / 100;
                    }

                    // Create new items with split metadata
                    const newItems = await InvoiceItem.create(
                        data.items.map(item => ({
                            invoiceId,
                            name: item.name,
                            amount: item.amount,
                            splitType: item.splitType || 'EQUAL',
                            assignedTo: item.assignedTo,
                            splits: item.splits || []
                        })),
                        { session, ordered: true }
                    );

                    // Recreate debts only for SUBMITTED invoices.
                    // DRAFT invoices (recurring templates) skip debt creation —
                    // debts are created later in confirmDraft() when the owner confirms.
                    if (invoice.status !== 'DRAFT') {
                        const isForeignCurrency = invoice.exchangeRate != null && invoice.baseCurrency != null;
                        const debtMap = new Map<string, number>();

                        for (let i = 0; i < newItems.length; i++) {
                            const dbItem = newItems[i];
                            const inputItem = data.items[i];
                            if (dbItem.assignedTo.length === 0) continue;
                            for (const debtorId of dbItem.assignedTo) {
                                if (debtorId === userId) continue;
                                const share = calculateShareForUser(
                                    { amount: dbItem.amount, assignedTo: dbItem.assignedTo, splitType: dbItem.splitType, splits: inputItem.splits },
                                    debtorId
                                );
                                debtMap.set(debtorId, (debtMap.get(debtorId) || 0) + share);
                            }
                        }

                        const now = new Date();
                        const debts = Array.from(debtMap.entries()).map(([debtorId, amountInCurrency]) => {
                            // amountInCurrency is already floored from calculateShareForUser
                            const amountInBase = isForeignCurrency
                                ? Math.floor(amountInCurrency * invoice.exchangeRate!)
                                : amountInCurrency;
                            const amountInCurrencyRounded = amountInCurrency;

                            return {
                                groupId,
                                invoiceId,
                                debtorId,
                                creditorId: userId,
                                originalAmount: amountInBase,
                                remainingAmount: amountInBase,
                                ...(isForeignCurrency ? {
                                    originalCurrency: invoice.currency,
                                    originalAmountInCurrency: amountInCurrencyRounded,
                                    exchangeRateUsed: invoice.exchangeRate,
                                    rateLockedAt: now
                                } : {})
                            };
                        });

                        if (debts.length > 0) {
                            await OriginalDebt.create(debts, { session, ordered: true });
                        }
                    }

                }

                await invoice.save({ session });
            });
        } finally {
            session.endSession();
        }

        await invalidateInvoiceCache(groupId);

        return this.getInvoiceById(userId, groupId, invoiceId);
    },

    /**
     * Delete invoice (only if not locked)
     */
    async deleteInvoice(userId: string, groupId: string, invoiceId: string): Promise<void> {
        const invoice = await Invoice.findOne({ _id: invoiceId, groupId });
        if (!invoice) {
            throw new Error('Invoice not found');
        }

        if (invoice.uploadedBy !== userId) {
            throw new Error('Only the uploader can delete this invoice');
        }

        if (invoice.isLocked) {
            throw new Error('Cannot delete locked invoice');
        }

        const session = await mongoose.startSession();
        try {
            await session.withTransaction(async () => {
                // Delete associated original debts
                await OriginalDebt.deleteMany({ invoiceId }, { session });
                // Delete invoice items
                await InvoiceItem.deleteMany({ invoiceId }, { session });
                // Delete invoice
                await Invoice.deleteOne({ _id: invoiceId }, { session });
            });
        } finally {
            session.endSession();
        }

        await invalidateInvoiceCache(groupId);
    },

    /**
     * Submit invoice - DEPRECATED: Invoices are now created with SUBMITTED status
     * This function is kept for backwards compatibility
     */
    async submitInvoice(userId: string, groupId: string, invoiceId: string): Promise<InvoiceResponse> {
        const invoice = await Invoice.findOne({ _id: invoiceId, groupId });
        if (!invoice) {
            throw new Error('Invoice not found');
        }

        if (invoice.uploadedBy !== userId) {
            throw new Error('Only the uploader can access this invoice');
        }

        // Invoices are now created as SUBMITTED, so just return the invoice
        return this.getInvoiceById(userId, groupId, invoiceId);
    },

    /**
     * Create adjustment invoice (for corrections after request is partially paid)
     */
    async createAdjustmentInvoice(
        userId: string,
        groupId: string,
        originalInvoiceId: string,
        data: CreateInvoiceRequest
    ): Promise<InvoiceResponse> {
        const originalInvoice = await Invoice.findOne({ _id: originalInvoiceId, groupId });
        if (!originalInvoice) {
            throw new Error('Original invoice not found');
        }

        // Create adjustment with reference to original
        const adjustmentData = {
            ...data,
            title: `[Điều chỉnh] ${data.title}`
        };

        const result = await this.createInvoice(userId, groupId, adjustmentData);

        // Mark as adjustment
        await Invoice.findByIdAndUpdate(result.id, {
            isAdjustment: true,
            originalInvoiceId
        });

        await invalidateInvoiceCache(groupId);

        return this.getInvoiceById(userId, groupId, result.id);
    }
};
