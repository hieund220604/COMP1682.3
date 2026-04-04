import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IReceipt extends Document {
    _id: Types.ObjectId;
    userId: string;
    imageUrl: string;
    note?: string;
    tags: Types.ObjectId[];
    receiptDate: Date; // normalized UTC midnight
    createdAt: Date;
    updatedAt: Date;
}

const ReceiptSchema = new Schema<IReceipt>({
    userId: {
        type: String,
        required: true,
        index: true,
        ref: 'User'
    },
    imageUrl: {
        type: String,
        required: true,
        trim: true,
    },
    note: {
        type: String,
        default: null,
        maxlength: 500,
        trim: true,
    },
    tags: {
        type: [Schema.Types.ObjectId],
        ref: 'ReceiptTag',
        required: true,
        validate: {
            validator: function (v: Types.ObjectId[]) {
                return Array.isArray(v) && v.length > 0;
            },
            message: 'At least one tag is required'
        }
    },
    receiptDate: {
        type: Date,
        required: true,
        index: true,
    }
}, {
    timestamps: true,
    collection: 'receipts'
});

// Indexes for queries
ReceiptSchema.index({ userId: 1, receiptDate: 1 });
ReceiptSchema.index({ userId: 1, tags: 1 });
ReceiptSchema.index({ userId: 1, createdAt: -1 });

export const Receipt = mongoose.model<IReceipt>('Receipt', ReceiptSchema);
