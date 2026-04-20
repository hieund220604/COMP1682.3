import mongoose, { Schema, Document, Types } from 'mongoose';

export type BillingStatus = 'SUCCESS' | 'FAILED' | 'PARTIAL';

export interface IBillingHistory extends Document {
    _id: Types.ObjectId;
    subscriptionId: string;
    groupId: string;
    billingDate: Date;
    amount: number;
    currency: string;
    status: BillingStatus;
    membersCharged: number;
    membersFailed: number;
    totalCollected: number;
    failureReason?: string;
    memberResults: {
        userId: string;
        shareAmount: number;
        success: boolean;
        reason?: string;
        categoryTagId?: string;
    }[];
    createdAt: Date;
}

const BillingHistorySchema = new Schema<IBillingHistory>({
    subscriptionId: {
        type: String,
        required: true,
        ref: 'Subscription',
        index: true
    },
    groupId: {
        type: String,
        required: true,
        ref: 'Group',
        index: true
    },
    billingDate: {
        type: Date,
        required: true,
        default: Date.now
    },
    amount: {
        type: Number,
        required: true
    },
    currency: {
        type: String,
        default: 'VND'
    },
    status: {
        type: String,
        enum: ['SUCCESS', 'FAILED', 'PARTIAL'],
        required: true
    },
    membersCharged: {
        type: Number,
        default: 0
    },
    membersFailed: {
        type: Number,
        default: 0
    },
    totalCollected: {
        type: Number,
        default: 0
    },
    failureReason: {
        type: String,
        default: null
    },
    memberResults: [{
        userId: { type: String, required: true },
        shareAmount: { type: Number, required: true },
        success: { type: Boolean, required: true },
        reason: { type: String, default: null },
        categoryTagId: { type: String, default: null }
    }]
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'billing_history'
});

BillingHistorySchema.index({ subscriptionId: 1, billingDate: -1 });
BillingHistorySchema.index({ groupId: 1, billingDate: -1 });

export const BillingHistory = mongoose.model<IBillingHistory>('BillingHistory', BillingHistorySchema);
