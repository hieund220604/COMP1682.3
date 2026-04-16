import mongoose, { Schema, Document, Types } from 'mongoose';

export type BillingCycle = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY';
export type SubscriptionStatus = 'ACTIVE' | 'PAUSED' | 'CANCELLED' | 'EXPIRED' | 'PAST_DUE';

export interface ISubscription extends Document {
    _id: Types.ObjectId;
    groupId: string;
    name: string;
    description?: string;
    amount: number;
    currency: string;
    billingCycle: BillingCycle;
    status: SubscriptionStatus;
    nextBillingDate: Date;
    lastBilledAt?: Date;
    createdBy: string;
    createdAt: Date;
    cancelledAt?: Date;
    // New fields for retry logic
    retryCount: number;
    failureReason?: string;
    lastAttemptAt?: Date;
    groupDeleted: boolean;  // True if group was deleted
}

const SubscriptionSchema = new Schema<ISubscription>({
    groupId: {
        type: String,
        required: true,
        ref: 'Group'
    },
    name: {
        type: String,
        required: true,
        trim: true
    },
    description: {
        type: String,
        default: null
    },
    amount: {
        type: Number,
        required: true
    },
    currency: {
        type: String,
        default: 'VND',
        uppercase: true
    },
    billingCycle: {
        type: String,
        enum: ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'],
        required: true
    },
    status: {
        type: String,
        enum: ['ACTIVE', 'PAUSED', 'CANCELLED', 'EXPIRED', 'PAST_DUE'],
        default: 'ACTIVE'
    },
    retryCount: {
        type: Number,
        default: 0
    },
    failureReason: {
        type: String,
        default: null
    },
    lastAttemptAt: {
        type: Date,
        default: null
    },
    nextBillingDate: {
        type: Date,
        required: true
    },
    lastBilledAt: {
        type: Date,
        default: null
    },
    createdBy: {
        type: String,
        required: true,
        ref: 'User'
    },
    cancelledAt: {
        type: Date,
        default: null
    },
    groupDeleted: {
        type: Boolean,
        default: false
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'subscriptions'
});

// Indexes
SubscriptionSchema.index({ groupId: 1 });
SubscriptionSchema.index({ status: 1 });
SubscriptionSchema.index({ nextBillingDate: 1 });

export const Subscription = mongoose.model<ISubscription>('Subscription', SubscriptionSchema);
