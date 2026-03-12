import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IInvoiceItemSplit {
    userId: string;
    value: number;
}

export interface IInvoiceItem extends Document {
    _id: Types.ObjectId;
    invoiceId: string;
    name: string;
    amount: number;
    splitType: 'EQUAL' | 'PERCENTAGE' | 'CUSTOM' | 'WEIGHT';
    assignedTo: string[];  // List of userIds who share this item
    splits: IInvoiceItemSplit[]; // Per-user split values (empty for EQUAL)
}

const InvoiceItemSplitSchema = new Schema<IInvoiceItemSplit>({
    userId: { type: String, required: true },
    value:  { type: Number, required: true }
}, { _id: false });

const InvoiceItemSchema = new Schema<IInvoiceItem>({
    invoiceId: {
        type: String,
        required: true,
        ref: 'Invoice',
        index: true
    },
    name: {
        type: String,
        required: true,
        trim: true
    },
    amount: {
        type: Number,
        required: true
    },
    splitType: {
        type: String,
        enum: ['EQUAL', 'PERCENTAGE', 'CUSTOM', 'WEIGHT'],
        default: 'EQUAL'
    },
    assignedTo: [{
        type: String,
        ref: 'User'
    }],
    splits: {
        type: [InvoiceItemSplitSchema],
        default: []
    }
}, {
    timestamps: false,
    collection: 'invoice_items'
});

// Indexes


export const InvoiceItem = mongoose.model<IInvoiceItem>('InvoiceItem', InvoiceItemSchema);
