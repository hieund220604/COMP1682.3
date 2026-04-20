import mongoose, { Schema, Document, Types } from 'mongoose';

export type SubscriptionMemberStatus = 'ACTIVE' | 'LEFT';

export interface ISubscriptionMember extends Document {
    _id: Types.ObjectId;
    subscriptionId: string;
    userId: string;
    /** Amount frozen from Subscription.amount at the time of joining */
    amount: number;
    status: SubscriptionMemberStatus;
    joinedAt: Date;
    /** nextBillingDate = joinedAt + 1 billingCycle, updated after each successful charge */
    nextBillingDate: Date;
    /** Timestamp of last successful charge (used for idempotency & leave obligation check) */
    lastChargedAt: Date;
    /** Number of failed billing attempts in the current retry window */
    retryCount: number;
    leftAt?: Date;
    categoryTagId?: string;
}

const SubscriptionMemberSchema = new Schema<ISubscriptionMember>({
    subscriptionId: {
        type: String,
        required: true,
        ref: 'Subscription'
    },
    userId: {
        type: String,
        required: true,
        ref: 'User'
    },
    amount: {
        type: Number,
        required: true
    },
    status: {
        type: String,
        enum: ['ACTIVE', 'LEFT'],
        default: 'ACTIVE'
    },
    joinedAt: {
        type: Date,
        default: Date.now
    },
    nextBillingDate: {
        type: Date,
        required: true
    },
    lastChargedAt: {
        type: Date,
        required: true
    },
    retryCount: {
        type: Number,
        default: 0
    },
    leftAt: {
        type: Date,
        default: null
    },
    categoryTagId: {
        type: String,
        ref: 'ReceiptTag',
        default: null
    }
}, {
    timestamps: false,
    collection: 'subscription_members'
});

SubscriptionMemberSchema.index({ subscriptionId: 1, userId: 1 }, { unique: true });
SubscriptionMemberSchema.index({ userId: 1 });
SubscriptionMemberSchema.index({ status: 1, nextBillingDate: 1 });

export const SubscriptionMember = mongoose.model<ISubscriptionMember>('SubscriptionMember', SubscriptionMemberSchema);
