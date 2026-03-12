import mongoose, { Schema, Document, Types } from 'mongoose';

export type TransactionType = 'TOP_UP' | 'WITHDRAWAL' | 'TRANSFER_SENT' | 'TRANSFER_RECEIVED' | 'TRANSFER_REFUND_SENT' | 'TRANSFER_REFUND_RECEIVED' | 'VNPAY_PAYMENT' | 'EXPENSE_PAYMENT' | 'SUBSCRIPTION_FEE' | 'REFUND' | 'SETTLEMENT_SENT' | 'SETTLEMENT_RECEIVED';

export interface ITransaction extends Document {
    _id: Types.ObjectId;
    userId: string;
    type: TransactionType;
    amount: number;
    balanceBefore: number;
    balanceAfter: number;
    currency: string;
    description?: string;
    referenceId?: string;
    referenceType?: string;
    createdAt: Date;
}

const TransactionSchema = new Schema<ITransaction>({
    userId: {
        type: String,
        required: true,
        ref: 'User'
    },
    type: {
        type: String,
        enum: ['TOP_UP', 'WITHDRAWAL', 'TRANSFER_SENT', 'TRANSFER_RECEIVED', 'TRANSFER_REFUND_SENT', 'TRANSFER_REFUND_RECEIVED', 'VNPAY_PAYMENT', 'EXPENSE_PAYMENT', 'SUBSCRIPTION_FEE', 'REFUND', 'SETTLEMENT_SENT', 'SETTLEMENT_RECEIVED'],
        required: true
    },
    amount: {
        type: Number,
        required: true
    },
    balanceBefore: {
        type: Number,
        required: true
    },
    balanceAfter: {
        type: Number,
        required: true
    },
    currency: {
        type: String,
        default: 'VND',
        uppercase: true
    },
    description: {
        type: String,
        default: null
    },
    referenceId: {
        type: String,
        default: null
    },
    referenceType: {
        type: String,
        default: null
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'transactions'
});

// Indexes
TransactionSchema.index({ userId: 1, createdAt: -1 });
TransactionSchema.index({ type: 1 });
TransactionSchema.index({ referenceId: 1 });

export const Transaction = mongoose.model<ITransaction>('Transaction', TransactionSchema);
