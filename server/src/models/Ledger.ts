import mongoose, { Schema, Document, Types } from 'mongoose';

export enum LedgerType {
    EXPENSE_PAID = 'EXPENSE_PAID',
    EXPENSE_SHARE = 'EXPENSE_SHARE',
    PAYMENT = 'PAYMENT',
    REFUND = 'REFUND'
}

export interface ILedger extends Document {
    _id: Types.ObjectId;
    groupId: string;
    userId: string;
    amount: number;
    type: LedgerType;
    referenceId: string;
    referenceType: string;
    description: string;
    createdAt: Date;
}

const ledgerSchema = new Schema<ILedger>({
    groupId: { type: String, required: true, index: true },
    userId: { type: String, required: true, index: true },
    amount: { type: Number, required: true },
    type: { type: String, enum: Object.values(LedgerType), required: true },
    referenceId: { type: String, required: true },
    referenceType: { type: String, required: true },
    description: { type: String, required: true },
    createdAt: { type: Date, default: Date.now, index: true }
});

// Compound indexes for efficient queries
ledgerSchema.index({ groupId: 1, userId: 1 });
ledgerSchema.index({ groupId: 1, createdAt: -1 });
ledgerSchema.index({ referenceId: 1, referenceType: 1 });

export const Ledger = mongoose.model<ILedger>('Ledger', ledgerSchema);
