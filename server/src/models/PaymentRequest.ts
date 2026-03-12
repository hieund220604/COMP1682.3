import mongoose, { Schema, Document, Types } from 'mongoose';

export type PaymentRequestStatus = 'ISSUED' | 'PARTIALLY_PAID' | 'PAID' | 'CANCELLED';

export interface IPaymentRequest extends Document {
    _id: Types.ObjectId;
    groupId: string;
    createdBy: string;        // OWNER/ADMIN who created
    invoiceIds: string[];     // List of invoices in this request
    status: PaymentRequestStatus;
    issuedAt: Date;
    paidAt?: Date;
    cancelledAt?: Date;
    createdAt: Date;
}

const PaymentRequestSchema = new Schema<IPaymentRequest>({
    groupId: {
        type: String,
        required: true,
        ref: 'Group',
        index: true
    },
    createdBy: {
        type: String,
        required: true,
        ref: 'User'
    },
    invoiceIds: [{
        type: String,
        ref: 'Invoice'
    }],
    status: {
        type: String,
        enum: ['ISSUED', 'PARTIALLY_PAID', 'PAID', 'CANCELLED'],
        default: 'ISSUED'
    },
    issuedAt: {
        type: Date,
        default: Date.now
    },
    paidAt: {
        type: Date,
        default: null
    },
    cancelledAt: {
        type: Date,
        default: null
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'payment_requests'
});

// Indexes
PaymentRequestSchema.index({ groupId: 1, status: 1 });
PaymentRequestSchema.index({ createdBy: 1 });

export const PaymentRequest = mongoose.model<IPaymentRequest>('PaymentRequest', PaymentRequestSchema);
