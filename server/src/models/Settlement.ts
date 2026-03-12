import mongoose, { Schema, Document, Types } from 'mongoose';

export type SettlementStatus = 'PENDING' | 'COMPLETED' | 'FAILED';

export interface ISettlement extends Document {
    _id: Types.ObjectId;
    groupId: string;
    fromUserId: string;
    toUserId: string;
    amount: number;
    currency: string;
    status: SettlementStatus;
    note?: string | null;
    settlementDate?: Date | null;
    vnpayTxnRef?: string | null;
    vnpayTransDate?: Date | null;
    createdAt: Date;
}

const SettlementSchema = new Schema<ISettlement>({
    groupId: {
        type: String,
        required: true,
        ref: 'Group'
    },
    fromUserId: {
        type: String,
        required: true,
        ref: 'User'
    },
    toUserId: {
        type: String,
        required: true,
        ref: 'User'
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
        enum: ['PENDING', 'COMPLETED', 'FAILED'],
        default: 'PENDING'
    },
    note: {
        type: String,
        default: null
    },
    settlementDate: {
        type: Date,
        default: null
    },
    vnpayTxnRef: {
        type: String,
        default: null
    },
    vnpayTransDate: {
        type: Date,
        default: null
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'settlements'
});

// Indexes
SettlementSchema.index({ groupId: 1 });
SettlementSchema.index({ fromUserId: 1 });
SettlementSchema.index({ toUserId: 1 });
SettlementSchema.index({ status: 1 });

export const Settlement = mongoose.model<ISettlement>('Settlement', SettlementSchema);
