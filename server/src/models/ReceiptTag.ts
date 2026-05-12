import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IReceiptTag extends Document {
    _id: Types.ObjectId;
    userId: string;
    name: string;
    color: string;
    monthlyBudget?: number;
    icon?: string;
    isArchived: boolean;
    createdAt: Date;
    updatedAt: Date;
}

const ReceiptTagSchema = new Schema<IReceiptTag>({
    userId: {
        type: String,
        required: true,
        index: true,
        ref: 'User'
    },
    name: {
        type: String,
        required: true,
        trim: true,
    },
    color: {
        type: String,
        required: true,
        trim: true,
    },
    monthlyBudget: {
        type: Number,
        default: null,
    },
    icon: {
        type: String,
        default: null,
        trim: true,
    },
    isArchived: {
        type: Boolean,
        default: false,
    }
}, {
    timestamps: true,
    collection: 'receipt_tags'
});

// Unique tag name per user
ReceiptTagSchema.index({ userId: 1, name: 1 }, { unique: true });
ReceiptTagSchema.index({ userId: 1, isArchived: 1 });

export const ReceiptTag = mongoose.model<IReceiptTag>('ReceiptTag', ReceiptTagSchema);
