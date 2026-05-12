import mongoose, { Schema, Document, Types } from 'mongoose';

export enum NotificationType {
    EXPENSE_CREATED = 'EXPENSE_CREATED',
    EXPENSE_UPDATED = 'EXPENSE_UPDATED',
    INVOICE_CREATED = 'INVOICE_CREATED',
    SETTLEMENT_CREATED = 'SETTLEMENT_CREATED',
    PAYMENT_RECEIVED = 'PAYMENT_RECEIVED',
    INVITE_RECEIVED = 'INVITE_RECEIVED',
    GROUP_JOINED = 'GROUP_JOINED',
    BALANCE_UPDATED = 'BALANCE_UPDATED',
    PAYMENT_REQUEST_CANCELLED = 'PAYMENT_REQUEST_CANCELLED',
    PAYMENT_REQUEST_REMINDER = 'PAYMENT_REQUEST_REMINDER',
    PAYMENT_REFUNDED = 'PAYMENT_REFUNDED',
    // ── Subscription ────────────────────────────────────────────
    SUBSCRIPTION_CANCELLED = 'SUBSCRIPTION_CANCELLED',
    SUBSCRIPTION_BILLING_SUCCESS = 'SUBSCRIPTION_BILLING_SUCCESS',
    SUBSCRIPTION_BILLING_FAILED = 'SUBSCRIPTION_BILLING_FAILED',
    SUBSCRIPTION_BILLING_WARNING = 'SUBSCRIPTION_BILLING_WARNING',
    SUB_INVITE_RECEIVED = 'SUB_INVITE_RECEIVED',
    SUB_INVITE_ACCEPTED = 'SUB_INVITE_ACCEPTED',
    SUB_INVITE_DECLINED = 'SUB_INVITE_DECLINED',
    SUBSCRIPTION_MEMBER_KICKED = 'SUBSCRIPTION_MEMBER_KICKED',
    SUBSCRIPTION_MEMBER_LEFT = 'SUBSCRIPTION_MEMBER_LEFT',
    // ── Recurring Bills ──────────────────────────────────────────
    RECURRING_BILL_DRAFT = 'RECURRING_BILL_DRAFT',
    // ────────────────────────────────────────────────────────────
    ROLE_CHANGED = 'ROLE_CHANGED',
    BUDGET_ALERT = 'BUDGET_ALERT',
    // ── Savings ─────────────────────────────────────────────────
    SAVINGS_DEPOSIT_MATURED = 'SAVINGS_DEPOSIT_MATURED',
    SAVINGS_GOAL_COMPLETED = 'SAVINGS_GOAL_COMPLETED',
    SAVINGS_MATURITY_REMINDER = 'SAVINGS_MATURITY_REMINDER',
}

export interface INotification extends Document {
    _id: Types.ObjectId;
    userId: string;
    type: NotificationType;
    title: string;
    message: string;
    data?: any;
    read: boolean;
    sentEmail: boolean;
    createdAt: Date;
}

const notificationSchema = new Schema<INotification>({
    userId: { type: String, required: true, index: true },
    type: { type: String, enum: Object.values(NotificationType), required: true },
    title: { type: String, required: true },
    message: { type: String, required: true },
    data: { type: Schema.Types.Mixed },
    read: { type: Boolean, default: false, index: true },
    sentEmail: { type: Boolean, default: false },
    createdAt: { type: Date, default: Date.now, index: true }
});

// Compound indexes
notificationSchema.index({ userId: 1, read: 1, createdAt: -1 });
notificationSchema.index({ userId: 1, createdAt: -1 });

export const Notification = mongoose.model<INotification>('Notification', notificationSchema);
