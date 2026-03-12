import mongoose, { Schema, Document, Types } from 'mongoose';

export type WithdrawalStatus = 'PENDING' | 'OTP_SENT' | 'PROCESSING' | 'COMPLETED' | 'REJECTED';

export interface IWithdrawal extends Document {
    _id: Types.ObjectId;
    userId: string;
    amount: number;
    currency: string;
    accountNumber: string;
    bankName: string;
    accountName: string;
    status: WithdrawalStatus;
    otp?: string | null;
    otpExpiresAt?: Date | null;
    verifiedAt?: Date | null;
    processedAt?: Date | null;
    createdAt: Date;
}

const WithdrawalSchema = new Schema<IWithdrawal>({
    userId: {
        type: String,
        required: true,
        ref: 'User'
    },
    amount: {
        type: Number,
        required: true
    },
    currency: {
        type: String,
        default: 'VND'
    },
    accountNumber: {
        type: String,
        required: true
    },
    bankName: {
        type: String,
        required: true
    },
    accountName: {
        type: String,
        required: true
    },
    status: {
        type: String,
        enum: ['PENDING', 'OTP_SENT', 'PROCESSING', 'COMPLETED', 'REJECTED'],
        default: 'PENDING'
    },
    otp: {
        type: String,
        default: null
    },
    otpExpiresAt: {
        type: Date,
        default: null
    },
    verifiedAt: {
        type: Date,
        default: null
    },
    processedAt: {
        type: Date,
        default: null
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'withdrawals'
});

// Indexes
WithdrawalSchema.index({ userId: 1 });
WithdrawalSchema.index({ status: 1 });

export const Withdrawal = mongoose.model<IWithdrawal>('Withdrawal', WithdrawalSchema);
