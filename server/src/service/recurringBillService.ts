/**
 * Recurring Bill Service
 *
 * Handles auto-generation of Invoices from BillTemplates.
 *
 * Flow:
 *   1. Scheduler calls processAutoGenerate() every hour
 *   2. For each due ACTIVE template → create Invoice(status=DRAFT)
 *   3. Owner reviews DRAFT, edits amount if needed, then confirms
 *   4. confirmDraft() → validates, creates OriginalDebts, sets status=SUBMITTED
 *   5. From SUBMITTED onward: existing PaymentRequest flow takes over
 */

import mongoose from 'mongoose';
import { BillTemplate, BillTemplateCycle, IBillTemplate } from '../models/BillTemplate';
import { Invoice } from '../models/Invoice';
import { InvoiceItem } from '../models/InvoiceItem';
import { OriginalDebt } from '../models/OriginalDebt';
import { GroupMember } from '../models/GroupMember';
import { Group } from '../models/Group';
import { User } from '../models/User';
import { PaymentRequest } from '../models/PaymentRequest';
import { notificationService } from './notificationService';
import { NotificationType } from '../models/Notification';
import { buildRedisKey, deleteKeysByPrefix } from '../redis';
import { invoiceService } from './invoiceService';

// ── Helpers ────────────────────────────────────────────────────────────────────

/**
 * Calculate the next billing date from a given date, based on cycle and billingDay.
 */
function calculateNextBillDate(cycle: BillTemplateCycle, billingDay: number | undefined, fromDate: Date): Date {
    const now = new Date(fromDate);

    switch (cycle) {
        case 'DAILY': {
            const next = new Date(now);
            next.setUTCDate(next.getUTCDate() + 1);
            next.setUTCHours(0, 5, 0, 0); // 00:05 UTC
            return next;
        }
        case 'WEEKLY': {
            // billingDay: 1=Monday, 7=Sunday
            const day = billingDay ?? 1;
            const next = new Date(now);
            const currentDay = next.getUTCDay() || 7; // convert Sun=0 to 7
            const daysUntilNext = ((day - currentDay + 7) % 7) || 7;
            next.setUTCDate(next.getUTCDate() + daysUntilNext);
            next.setUTCHours(0, 5, 0, 0);
            return next;
        }
        case 'MONTHLY': {
            const day = billingDay ?? 1;
            const next = new Date(now);
            // Move to next month, same day
            next.setUTCMonth(next.getUTCMonth() + 1);
            next.setUTCDate(Math.min(day, 28)); // cap at 28 to avoid month overflow
            next.setUTCHours(0, 5, 0, 0);
            return next;
        }
    }
}

/**
 * Compute billing period string for idempotency key.
 * DAILY   → "2026-04-21"
 * WEEKLY  → "2026-W17"
 * MONTHLY → "2026-05"
 */
function computeBillingPeriod(cycle: BillTemplateCycle, date: Date): string {
    const y = date.getUTCFullYear();
    const m = String(date.getUTCMonth() + 1).padStart(2, '0');
    const d = String(date.getUTCDate()).padStart(2, '0');

    if (cycle === 'DAILY') return `${y}-${m}-${d}`;
    if (cycle === 'MONTHLY') return `${y}-${m}`;

    // WEEKLY: ISO week number
    const jan1 = new Date(Date.UTC(y, 0, 1));
    const weekNum = Math.ceil(((date.getTime() - jan1.getTime()) / 86400000 + jan1.getUTCDay() + 1) / 7);
    return `${y}-W${String(weekNum).padStart(2, '0')}`;
}

/**
 * Build invoice title: "Tiền điện - Tháng 5/2026" / "Tháng" / "Ngày" / "Tuần"
 */
function buildInvoiceTitle(templateName: string, cycle: BillTemplateCycle, date: Date): string {
    const y = date.getUTCFullYear();
    const m = date.getUTCMonth() + 1;
    const d = date.getUTCDate();

    switch (cycle) {
        case 'DAILY':
            return `${templateName} - Day ${d}/${m}/${y}`;
        case 'WEEKLY': {
            const jan1 = new Date(Date.UTC(y, 0, 1));
            const weekNum = Math.ceil(((date.getTime() - jan1.getTime()) / 86400000 + jan1.getUTCDay() + 1) / 7);
            return `${templateName} - Week ${weekNum}/${y}`;
        }
        case 'MONTHLY':
            return `${templateName} - Month ${m}/${y}`;
    }
}

/**
 * Calculate per-user share for one invoice item.
 * Mirrors calculateShareForUser from invoiceService.
 */
function calculateShareForUser(
    item: { amount: number; assignedTo: string[]; splitType: string; splits?: { userId: string; value: number }[] },
    debtorId: string
): number {
    switch (item.splitType) {
        case 'PERCENTAGE': {
            const split = item.splits?.find(s => s.userId === debtorId);
            return split ? Math.floor(item.amount * (split.value / 100)) : 0;
        }
        case 'CUSTOM': {
            const split = item.splits?.find(s => s.userId === debtorId);
            return split ? split.value : 0;
        }
        case 'WEIGHT': {
            const totalWeight = item.splits?.reduce((s, x) => s + x.value, 0) || 1;
            const split = item.splits?.find(s => s.userId === debtorId);
            return split ? Math.floor(item.amount * (split.value / totalWeight)) : 0;
        }
        case 'EQUAL':
        default:
            return item.assignedTo.length > 0 ? Math.floor(item.amount / item.assignedTo.length) : 0;
    }
}

async function invalidateBillTemplateCache(groupId: string): Promise<void> {
    await deleteKeysByPrefix(buildRedisKey('cache', 'bill_template', groupId));
}

async function invalidateInvoiceCache(groupId: string): Promise<void> {
    await deleteKeysByPrefix(buildRedisKey('cache', 'invoice', groupId));
}

// ── Public API ─────────────────────────────────────────────────────────────────

export const recurringBillService = {

    // ── SCHEDULER: Auto-generate DRAFT invoices ────────────────────────────

    /**
     * Called by the scheduler every hour.
     * Finds all ACTIVE templates whose nextBillDate has passed,
     * creates a DRAFT Invoice for each, then notifies the Owner.
     */
    async processAutoGenerate(): Promise<{ generated: number; skipped: number; failed: number }> {
        const now = new Date();
        let generated = 0, skipped = 0, failed = 0;

        const dueTemplates = await BillTemplate.find({
            status: 'ACTIVE',
            nextBillDate: { $lte: now }
        });

        for (const template of dueTemplates) {
            const billingPeriod = computeBillingPeriod(template.billingCycle as BillTemplateCycle, now);

            // Idempotency: skip if already generated for this period
            const exists = await Invoice.findOne({
                templateId: template._id.toString(),
                billingPeriod
            });
            if (exists) { skipped++; continue; }

            try {
                // Snapshot active group members
                const activeMembers = await GroupMember.find({
                    groupId: template.groupId,
                    leftAt: null
                }).select('userId');
                const memberIds = activeMembers.map(m => m.userId);

                if (memberIds.length === 0) {
                    skipped++;
                    continue;
                }

                // Build resolved items:
                // If template item has no assignedTo → use all active members
                const resolvedItems = template.items.map(item => ({
                    name: item.name,
                    amount: item.amount,
                    splitType: item.splitType,
                    assignedTo: item.assignedTo.length > 0
                        ? item.assignedTo.filter(uid => memberIds.includes(uid))
                        : memberIds,
                    splits: item.splits ?? []
                }));

                const title = buildInvoiceTitle(template.name, template.billingCycle as BillTemplateCycle, now);
                const amountTotal = resolvedItems.reduce((s, i) => s + i.amount, 0);

                // Create DRAFT Invoice (no OriginalDebt yet — waits for confirm)
                const session = await mongoose.startSession();
                let invoiceId: string;
                try {
                    session.startTransaction();

                    const [invoice] = await Invoice.create([{
                        groupId: template.groupId,
                        title,
                        amountTotal,
                        currency: template.currency,
                        uploadedBy: template.payerId,
                        invoiceDate: now,
                        note: `Recurring bill - auto-generated from "${template.name}"`,
                        status: 'DRAFT',
                        templateId: template._id.toString(),
                        billingPeriod,
                        isLocked: false,
                        isAdjustment: false,
                        groupDeleted: false,
                    }], { session });

                    invoiceId = invoice._id.toString();

                    await InvoiceItem.insertMany(
                        resolvedItems.map(item => ({
                            invoiceId,
                            name: item.name,
                            amount: item.amount,
                            splitType: item.splitType,
                            assignedTo: item.assignedTo,
                            splits: item.splits
                        })),
                        { session }
                    );

                    // Update template tracking
                    await BillTemplate.findByIdAndUpdate(template._id, {
                        lastGeneratedAt: now,
                        nextBillDate: calculateNextBillDate(
                            template.billingCycle as BillTemplateCycle,
                            template.billingDay,
                            now
                        )
                    }, { session });

                    await session.commitTransaction();
                } catch (err) {
                    await session.abortTransaction();
                    throw err;
                } finally {
                    session.endSession();
                }

                // Notify OWNER (payer) only — members not notified until confirm
                try {
                    await notificationService.notify(
                        template.payerId,
                        NotificationType.RECURRING_BILL_DRAFT,
                        'Recurring bill needs confirmation',
                        `Invoice "${title}" was auto-generated. Review and confirm to send to members.`,
                        { invoiceId: invoiceId!, groupId: template.groupId, templateId: template._id.toString() }
                    );
                } catch (_) { /* Notification failure should not block */ }

                await invalidateInvoiceCache(template.groupId);
                generated++;

            } catch (err) {
                console.error(`[RecurringBill] Failed to generate for template ${template._id}:`, err);
                failed++;
            }
        }

        return { generated, skipped, failed };
    },

    // ── CONFIRM DRAFT ──────────────────────────────────────────────────────

    /**
     * Owner/Admin confirms a DRAFT invoice.
     * Validates all required fields, creates OriginalDebts,
     * changes status to SUBMITTED, and notifies all assigned members.
     */
    async confirmDraft(userId: string, groupId: string, invoiceId: string): Promise<any> {
        // Auth: only Owner/Admin
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership || membership.role === 'USER') {
            throw new Error('Only group Owner or Admin can confirm a recurring bill');
        }

        const invoice = await Invoice.findOne({ _id: invoiceId, groupId });
        if (!invoice) throw new Error('Invoice not found');
        if (invoice.status !== 'DRAFT') throw new Error('Invoice is not in DRAFT status');

        const items = await InvoiceItem.find({ invoiceId });
        if (items.length === 0) throw new Error('Invoice has no items');

        // Validation: all items must have amount > 0
        const zeroItems = items.filter(i => i.amount <= 0);
        if (zeroItems.length > 0) {
            const names = zeroItems.map(i => `"${i.name}"`).join(', ');
            throw new Error(`The following items have no amount: ${names}. Please edit before confirming.`);
        }

        // Validation: all items must have at least one assignedTo
        const emptyItems = items.filter(i => i.assignedTo.length === 0);
        if (emptyItems.length > 0) {
            throw new Error('Some items have no assigned members. Please review.');
        }

        // Validation: block if group has an active payment request
        const activePaymentRequest = await PaymentRequest.findOne({
            groupId,
            status: { $in: ['ISSUED', 'PARTIALLY_PAID'] }
        });
        if (activePaymentRequest) {
            throw new Error('Cannot confirm invoice while there is an active payment request. Please wait until the current payment request is completed or cancelled.');
        }

        // Build debt map (mirrors invoiceService logic)
        const debtMap = new Map<string, number>();
        for (const item of items) {
            for (const debtorId of item.assignedTo) {
                if (debtorId === invoice.uploadedBy) continue; // creditor doesn't owe themselves
                const share = calculateShareForUser(
                    { amount: item.amount, assignedTo: item.assignedTo, splitType: item.splitType, splits: item.splits },
                    debtorId
                );
                if (share > 0) {
                    debtMap.set(debtorId, (debtMap.get(debtorId) || 0) + share);
                }
            }
        }

        const session = await mongoose.startSession();
        try {
            session.startTransaction();

            // Create OriginalDebts (amounts already floored from calculateShareForUser)
            const debts = Array.from(debtMap.entries()).map(([debtorId, amount]) => ({
                groupId,
                invoiceId,
                debtorId,
                creditorId: invoice.uploadedBy,
                originalAmount: amount,
                remainingAmount: amount,
            }));
            if (debts.length > 0) {
                await OriginalDebt.create(debts, { session, ordered: true });
            }

            // Transition: DRAFT → SUBMITTED
            await Invoice.findByIdAndUpdate(invoiceId, { status: 'SUBMITTED' }, { session });

            await session.commitTransaction();
        } catch (err) {
            await session.abortTransaction();
            throw err;
        } finally {
            session.endSession();
        }

        // Notify all assigned members (now that it's SUBMITTED)
        const allAssigned = [...new Set(items.flatMap(i => i.assignedTo))];
        const uploader = await User.findById(invoice.uploadedBy).select('displayName email');
        const uploaderName = uploader?.displayName || uploader?.email || 'Someone';

        for (const uid of allAssigned) {
            if (uid === invoice.uploadedBy) continue;
            try {
                await notificationService.createNotification({
                    userId: uid,
                    type: NotificationType.INVOICE_CREATED,
                    title: 'New Invoice',
                    message: `${uploaderName} added an invoice: ${invoice.title}`,
                    data: { invoiceId, groupId, title: invoice.title, amount: invoice.amountTotal }
                });
            } catch (_) { /* skip */ }
        }

        await invalidateInvoiceCache(groupId);
        return invoiceService.getInvoiceById(userId, groupId, invoiceId);
    },

    // ── TEMPLATE CRUD ──────────────────────────────────────────────────────

    async createTemplate(userId: string, groupId: string, data: {
        name: string;
        description?: string;
        billingCycle: BillTemplateCycle;
        billingDay?: number;
        currency?: string;
        items: IBillTemplate['items'];
        payerId?: string;
    }): Promise<any> {
        // Only Owner/Admin
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership || membership.role === 'USER') {
            throw new Error('Only group Owner or Admin can create bill templates');
        }

        const group = await Group.findById(groupId);
        if (!group) throw new Error('Group not found');

        const user = await User.findById(userId).select('isPro');
        if (!user) throw new Error('User not found');

        if (!user.isPro) {
            const templateCount = await BillTemplate.countDocuments({ createdBy: userId, status: { $ne: 'ARCHIVED' } });
            if (templateCount >= 2) {
                throw new Error('You have reached the limit for creating Templates on a free account. Please upgrade to Pro to create unlimited Templates.');
            }
        }

        // Validate items
        if (!data.items || data.items.length === 0) {
            throw new Error('Template must have at least one item');
        }

        for (const item of data.items) {
            if (!item.name?.trim()) throw new Error('Each item must have a name');
            if (item.amount < 0) throw new Error('Item amount cannot be negative');
            // Validate split consistency (mirrors invoiceService.validateItemSplits)
            if (item.splitType === 'PERCENTAGE' && item.splits?.length > 0) {
                const total = item.splits.reduce((s, x) => s + x.value, 0);
                if (Math.abs(total - 100) > 0.01) {
                    throw new Error(`Item "${item.name}": percentages must sum to 100, got ${total.toFixed(2)}`);
                }
            }
        }

        // Validate billingDay
        if (data.billingCycle === 'MONTHLY') {
            if (!data.billingDay || data.billingDay < 1 || data.billingDay > 28) {
                throw new Error('Monthly billing requires a billingDay between 1 and 28');
            }
        }
        if (data.billingCycle === 'WEEKLY') {
            if (!data.billingDay || data.billingDay < 1 || data.billingDay > 7) {
                throw new Error('Weekly billing requires a billingDay between 1 (Mon) and 7 (Sun)');
            }
        }

        const now = new Date();
        const nextBillDate = calculateNextBillDate(data.billingCycle, data.billingDay, now);

        const template = await BillTemplate.create({
            groupId,
            name: data.name.trim(),
            description: data.description ?? null,
            billingCycle: data.billingCycle,
            billingDay: data.billingDay ?? null,
            currency: data.currency?.toUpperCase() || group.baseCurrency || 'VND',
            items: data.items,
            payerId: data.payerId || userId,
            status: 'ACTIVE',
            createdBy: userId,
            nextBillDate,
        });

        await invalidateBillTemplateCache(groupId);
        return this.getTemplateById(userId, groupId, template._id.toString());
    },

    async getTemplates(userId: string, groupId: string): Promise<any[]> {
        // All members can see templates (but only Owner/Admin can manage them)
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) throw new Error('Not a member of this group');

        const templates = await BillTemplate.find({
            groupId,
            status: { $ne: 'ARCHIVED' }
        }).sort({ createdAt: -1 });

        return Promise.all(templates.map(t => this.formatTemplate(t)));
    },

    async getTemplateById(userId: string, groupId: string, templateId: string): Promise<any> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) throw new Error('Not a member of this group');

        const template = await BillTemplate.findOne({ _id: templateId, groupId });
        if (!template) throw new Error('Bill template not found');

        return this.formatTemplate(template);
    },

    async updateTemplate(userId: string, groupId: string, templateId: string, data: {
        name?: string;
        description?: string;
        billingCycle?: BillTemplateCycle;
        billingDay?: number;
        items?: IBillTemplate['items'];
        payerId?: string;
    }): Promise<any> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership || membership.role === 'USER') {
            throw new Error('Only group Owner or Admin can update bill templates');
        }

        const template = await BillTemplate.findOne({ _id: templateId, groupId });
        if (!template) throw new Error('Bill template not found');
        if (template.status === 'ARCHIVED') throw new Error('Cannot update an archived template');

        if (data.name) template.name = data.name.trim();
        if (data.description !== undefined) template.description = data.description;
        if (data.payerId) template.payerId = data.payerId;
        if (data.items) template.items = data.items;

        // If cycle/day changed → recalculate nextBillDate
        if (data.billingCycle || data.billingDay !== undefined) {
            if (data.billingCycle) template.billingCycle = data.billingCycle;
            if (data.billingDay !== undefined) template.billingDay = data.billingDay;
            template.nextBillDate = calculateNextBillDate(
                template.billingCycle as BillTemplateCycle,
                template.billingDay,
                new Date()
            );
        }

        await template.save();
        await invalidateBillTemplateCache(groupId);
        return this.formatTemplate(template);
    },

    async pauseTemplate(userId: string, groupId: string, templateId: string): Promise<void> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership || membership.role === 'USER') {
            throw new Error('Only group Owner or Admin can pause bill templates');
        }

        const template = await BillTemplate.findOne({ _id: templateId, groupId });
        if (!template) throw new Error('Bill template not found');
        if (template.status !== 'ACTIVE') throw new Error('Template is not active');

        await BillTemplate.findByIdAndUpdate(templateId, { status: 'PAUSED' });
        await invalidateBillTemplateCache(groupId);
    },

    async resumeTemplate(userId: string, groupId: string, templateId: string): Promise<void> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership || membership.role === 'USER') {
            throw new Error('Only group Owner or Admin can resume bill templates');
        }

        const template = await BillTemplate.findOne({ _id: templateId, groupId });
        if (!template) throw new Error('Bill template not found');
        if (template.status !== 'PAUSED') throw new Error('Template is not paused');

        // Recalculate nextBillDate from now
        const nextBillDate = calculateNextBillDate(
            template.billingCycle as BillTemplateCycle,
            template.billingDay,
            new Date()
        );

        await BillTemplate.findByIdAndUpdate(templateId, { status: 'ACTIVE', nextBillDate });
        await invalidateBillTemplateCache(groupId);
    },

    async archiveTemplate(userId: string, groupId: string, templateId: string): Promise<void> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership || membership.role === 'USER') {
            throw new Error('Only group Owner or Admin can archive bill templates');
        }

        const template = await BillTemplate.findOne({ _id: templateId, groupId });
        if (!template) throw new Error('Bill template not found');

        await BillTemplate.findByIdAndUpdate(templateId, { status: 'ARCHIVED' });
        await invalidateBillTemplateCache(groupId);
    },

    /**
     * Manual trigger: Owner wants to generate invoice right now without waiting for scheduler.
     */
    async generateNow(userId: string, groupId: string, templateId: string): Promise<any> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership || membership.role === 'USER') {
            throw new Error('Only group Owner or Admin can manually trigger invoice generation');
        }

        const template = await BillTemplate.findOne({ _id: templateId, groupId, status: 'ACTIVE' });
        if (!template) throw new Error('Active bill template not found');

        const now = new Date();
        const billingPeriod = computeBillingPeriod(template.billingCycle as BillTemplateCycle, now);

        // Idempotency check
        const exists = await Invoice.findOne({ templateId, billingPeriod });
        if (exists) {
            throw new Error('Invoice for this billing period has already been generated');
        }

        // Force processAutoGenerate for this single template
        // by temporarily setting nextBillDate to now
        await BillTemplate.findByIdAndUpdate(templateId, { nextBillDate: now });

        const result = await this.processAutoGenerate();
        if (result.generated === 0) {
            throw new Error('Failed to generate invoice');
        }

        // Return the newly created invoice
        const invoice = await Invoice.findOne({ templateId, billingPeriod });
        if (!invoice) throw new Error('Invoice generation failed unexpectedly');

        return invoiceService.getInvoiceById(userId, groupId, invoice._id.toString());
    },

    // ── Format helper ──────────────────────────────────────────────────────

    async formatTemplate(template: any): Promise<any> {
        const payer = await User.findById(template.payerId).select('_id email displayName avatarUrl');

        const daysUntilNext = Math.max(
            0,
            Math.ceil((template.nextBillDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
        );

        return {
            id: template._id.toString(),
            groupId: template.groupId,
            name: template.name,
            description: template.description ?? undefined,
            billingCycle: template.billingCycle,
            billingDay: template.billingDay ?? undefined,
            currency: template.currency,
            items: template.items.map((i: any) => ({
                name: i.name,
                amount: i.amount,
                splitType: i.splitType,
                assignedTo: i.assignedTo,
                splits: i.splits?.length > 0 ? i.splits : undefined,
            })),
            payer: payer ? {
                id: payer._id.toString(),
                email: payer.email,
                displayName: payer.displayName ?? undefined,
                avatarUrl: payer.avatarUrl ?? undefined,
            } : { id: template.payerId },
            status: template.status,
            createdBy: template.createdBy,
            lastGeneratedAt: template.lastGeneratedAt ?? undefined,
            nextBillDate: template.nextBillDate,
            daysUntilNext,
            createdAt: template.createdAt,
            updatedAt: template.updatedAt,
        };
    },
};
