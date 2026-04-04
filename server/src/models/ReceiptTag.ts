import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IReceiptTag extends Document {
    _id: Types.ObjectId;
    userId: string;
    name: string;
    color: string;
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
        lowercase: true,
    },
    color: {
        type: String,
        required: true,
        trim: true,
    }
}, {
    timestamps: true,
    collection: 'receipt_tags'
});

// Unique tag name per user
ReceiptTagSchema.index({ userId: 1, name: 1 }, { unique: true });

export const ReceiptTag = mongoose.model<IReceiptTag>('ReceiptTag', ReceiptTagSchema);
