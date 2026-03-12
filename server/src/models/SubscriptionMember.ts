import mongoose, { Schema, Document, Types } from 'mongoose';

export type SubscriptionMemberStatus = 'ACTIVE' | 'PAUSED' | 'LEFT';

export interface ISubscriptionMember extends Document {
    _id: Types.ObjectId;
    subscriptionId: string;
    userId: string;
    shareAmount: number;
    status: SubscriptionMemberStatus;
    joinedAt: Date;
    leftAt?: Date;
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
    shareAmount: {
        type: Number,
        required: true
    },
    status: {
        type: String,
        enum: ['ACTIVE', 'PAUSED', 'LEFT'],
        default: 'ACTIVE'
    },
    joinedAt: {
        type: Date,
        default: Date.now
    },
    leftAt: {
        type: Date,
        default: null
    }
}, {
    timestamps: false,
    collection: 'subscription_members'
});

// Indexes
SubscriptionMemberSchema.index({ subscriptionId: 1, userId: 1 }, { unique: true });
SubscriptionMemberSchema.index({ userId: 1 });
SubscriptionMemberSchema.index({ status: 1 });

export const SubscriptionMember = mongoose.model<ISubscriptionMember>('SubscriptionMember', SubscriptionMemberSchema);
