import mongoose, { Schema, Document, Types } from 'mongoose';

export type InvoiceStatus = 'SUBMITTED' | 'LOCKED';

export interface IInvoice extends Document {
    _id: Types.ObjectId;
    groupId: string;
    title: string;
    amountTotal: number;
    currency: string;
    uploadedBy: string;       // Member who uploaded
    invoiceDate: Date;
    imageUrl?: string;
    note?: string;

    // Multi-currency support
    convertedAmountTotal?: number;  // Amount in group baseCurrency (null if same currency)
    exchangeRate?: number;          // Rate used: 1 currency = X baseCurrency
    baseCurrency?: string;          // Group baseCurrency at creation time

    // Lock status
    isLocked: boolean;        // True when belongs to issued request
    paymentRequestId?: string; // Request containing this invoice

    // Adjustment
    isAdjustment: boolean;    // True if adjustment invoice
    originalInvoiceId?: string;

    groupDeleted: boolean;    // True if group was deleted
    status: InvoiceStatus;
    createdAt: Date;
    updatedAt: Date;
}

const InvoiceSchema = new Schema<IInvoice>({
    groupId: {
        type: String,
        required: true,
        ref: 'Group',
        index: true
    },
    title: {
        type: String,
        required: true,
        trim: true
    },
    amountTotal: {
        type: Number,
        required: true,
        default: 0
    },
    currency: {
        type: String,
        default: 'VND',
        uppercase: true
    },
    convertedAmountTotal: {
        type: Number,
        default: null
    },
    exchangeRate: {
        type: Number,
        default: null
    },
    baseCurrency: {
        type: String,
        default: null,
        uppercase: true
    },
    uploadedBy: {
        type: String,
        required: true,
        ref: 'User'
    },
    invoiceDate: {
        type: Date,
        default: Date.now
    },
    imageUrl: {
        type: String,
        default: null
    },
    note: {
        type: String,
        default: null
    },
    isLocked: {
        type: Boolean,
        default: false
    },
    paymentRequestId: {
        type: String,
        default: null,
        ref: 'PaymentRequest'
    },
    isAdjustment: {
        type: Boolean,
        default: false
    },
    originalInvoiceId: {
        type: String,
        default: null,
        ref: 'Invoice'
    },
    groupDeleted: {
        type: Boolean,
        default: false
    },
    status: {
        type: String,
        enum: ['SUBMITTED', 'LOCKED'],
        default: 'SUBMITTED'
    }
}, {
    timestamps: true,
    collection: 'invoices'
});

// Indexes
InvoiceSchema.index({ groupId: 1, status: 1 });
InvoiceSchema.index({ uploadedBy: 1 });
InvoiceSchema.index({ paymentRequestId: 1 });

export const Invoice = mongoose.model<IInvoice>('Invoice', InvoiceSchema);
