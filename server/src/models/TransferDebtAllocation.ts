import mongoose, { Schema, Document, Types } from 'mongoose';

export interface ITransferDebtAllocation extends Document {
    _id: Types.ObjectId;
    transferId: string;
    originalDebtId: string;
    allocatedAmount: number;  // Amount this transfer pays for this debt
}

const TransferDebtAllocationSchema = new Schema<ITransferDebtAllocation>({
    transferId: {
        type: String,
        required: true,
        ref: 'Transfer',
        index: true
    },
    originalDebtId: {
        type: String,
        required: true,
        ref: 'OriginalDebt',
        index: true
    },
    allocatedAmount: {
        type: Number,
        required: true
    }
}, {
    timestamps: false,
    collection: 'transfer_debt_allocations'
});

// Compound index for efficient lookups
TransferDebtAllocationSchema.index({ transferId: 1, originalDebtId: 1 });

export const TransferDebtAllocation = mongoose.model<ITransferDebtAllocation>('TransferDebtAllocation', TransferDebtAllocationSchema);
