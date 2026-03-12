import mongoose, { Schema, Document, Types } from 'mongoose';

export type TopUpStatus = 'PENDING' | 'COMPLETED' | 'FAILED';

export interface ITopUp extends Document {
    _id: Types.ObjectId;
    userId: string;
    amount: number;
    status: TopUpStatus;
    vnpayTxnRef?: string;
    createdAt: Date;
}

const TopUpSchema = new Schema<ITopUp>({
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
        enum: ['PENDING', 'COMPLETED', 'FAILED'],
        default: 'PENDING'
    },
    vnpayTxnRef: {
        type: String,
        default: null
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'topups'
});

// Indexes
TopUpSchema.index({ userId: 1 });
TopUpSchema.index({ status: 1 });
TopUpSchema.index({ vnpayTxnRef: 1 });

export const TopUp = mongoose.model<ITopUp>('TopUp', TopUpSchema);
