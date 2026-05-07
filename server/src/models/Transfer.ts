import mongoose, { Schema, Document, Types } from 'mongoose';

export type TransferStatus = 'PENDING' | 'COMPLETED' | 'FAILED' | 'CANCELLED';

export interface ITransfer extends Document {
    _id: Types.ObjectId;
    paymentRequestId: string;
    groupId: string;
    fromUserId: string;       // Payer
    toUserId: string;         // Receiver
    amount: number;           // Amount in group's baseCurrency
    status: TransferStatus;

    // Currency conversion info
    originalCurrency?: string;   // e.g. 'USD' - currency before conversion
    originalAmount?: number;     // Amount in original currency
    convertedCurrency?: string;  // Group baseCurrency (e.g. 'VND')
    exchangeRate?: number;       // Rate used: 1 originalCurrency = exchangeRate convertedCurrency

    // Payment info (Balance only for now)
    paidAt?: Date;

    // OTP verification
    otp?: string;
    otpExpiresAt?: Date;
    otpVerified: boolean;

    createdAt: Date;
    vnpayTxnRef?: string;
    vnpayTransDate?: Date;

    // Budget tagging
    categoryTagId?: string;
}

const TransferSchema = new Schema<ITransfer>({
    paymentRequestId: {
        type: String,
        required: true,
        ref: 'PaymentRequest',
        index: true
    },
    groupId: {
        type: String,
        required: true,
        ref: 'Group',
        index: true
    },
    fromUserId: {
        type: String,
        required: true,
        ref: 'User',
        index: true
    },
    toUserId: {
        type: String,
        required: true,
        ref: 'User',
        index: true
    },
    amount: {
        type: Number,
        required: true
    },
    status: {
        type: String,
        enum: ['PENDING', 'COMPLETED', 'FAILED', 'CANCELLED'],
        default: 'PENDING'
    },
    // Currency conversion fields
    originalCurrency: {
        type: String,
        default: null
    },
    originalAmount: {
        type: Number,
        default: null
    },
    convertedCurrency: {
        type: String,
        default: null
    },
    exchangeRate: {
        type: Number,
        default: null
    },
    paidAt: {
        type: Date,
        default: null
    },
    otp: {
        type: String,
        default: null
    },
    otpExpiresAt: {
        type: Date,
        default: null
    },
    otpVerified: {
        type: Boolean,
        default: false
    },
    vnpayTxnRef: {
        type: String,
        default: null
    },
    vnpayTransDate: {
        type: Date,
        default: null
    },
    categoryTagId: {
        type: String,
        ref: 'ReceiptTag',
        default: null
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'transfers'
});

// Compound indexes (ESR: Equality → Sort → Range)
TransferSchema.index({ fromUserId: 1, status: 1 });   // forecastService, budgetService, personal dashboard
TransferSchema.index({ toUserId: 1, status: 1 });     // forecastService, personal dashboard (theyOwe aggregate)
TransferSchema.index({ groupId: 1, status: 1 });      // group dashboard: pending transfers aggregate
TransferSchema.index({ groupId: 1, createdAt: -1 });  // group dashboard: recent transfers sort

export const Transfer = mongoose.model<ITransfer>('Transfer', TransferSchema);
