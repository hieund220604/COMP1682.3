import mongoose, { Schema, Document, Types } from 'mongoose';

export type BillingCycle = 'DAILY' | 'WEEKLY' | 'MONTHLY' | 'YEARLY';
export type SubscriptionStatus = 'ACTIVE' | 'CANCELLED';

export interface ISubscription extends Document {
    _id: Types.ObjectId;
    groupId?: string;
    name: string;
    description?: string;
    /** Fixed fee per member per cycle (VND). NOT a total to be split. */
    amount: number;
    currency: string;
    billingCycle: BillingCycle;
    /** ACTIVE = owner hasn't cancelled. CANCELLED = owner closed. No billing meaning. */
    status: SubscriptionStatus;
    createdBy: string;
    createdAt: Date;
    cancelledAt?: Date;
}

const SubscriptionSchema = new Schema<ISubscription>({
    groupId: {
        type: String,
        default: null,
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
        enum: ['ACTIVE', 'CANCELLED'],
        default: 'ACTIVE'
    },
    createdBy: {
        type: String,
        required: true,
        ref: 'User'
    },
    cancelledAt: {
        type: Date,
        default: null
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'subscriptions'
});

SubscriptionSchema.index({ groupId: 1 });
SubscriptionSchema.index({ status: 1 });
SubscriptionSchema.index({ createdBy: 1 });

export const Subscription = mongoose.model<ISubscription>('Subscription', SubscriptionSchema);
