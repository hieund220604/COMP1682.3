import mongoose, { Schema, Document, Types } from 'mongoose';

export enum PaymentMethod {
    BALANCE = 'BALANCE',
    VNPAY = 'VNPAY'
}

export enum PaymentIntentStatus {
    PENDING = 'PENDING',
    COMPLETED = 'COMPLETED',
    FAILED = 'FAILED',
    EXPIRED = 'EXPIRED'
}

export interface PaymentPlan {
    from: string;
    to: string;
    amount: number;
}

export interface IPaymentIntent extends Document {
    _id: Types.ObjectId;
    groupId: string;
    payerId: string;
    method: PaymentMethod;
    plan: PaymentPlan[];
    totalAmount: number;
    status: PaymentIntentStatus;
    vnpayTxnRef?: string;
    createdAt: Date;
    expiresAt: Date;
    completedAt?: Date;
}

const paymentIntentSchema = new Schema<IPaymentIntent>({
    groupId: { type: String, required: true, index: true },
    payerId: { type: String, required: true, index: true },
    method: { type: String, enum: Object.values(PaymentMethod), required: true },
    plan: [{
        from: { type: String, required: true },
        to: { type: String, required: true },
        amount: { type: Number, required: true }
    }],
    totalAmount: { type: Number, required: true },
    status: {
        type: String,
        enum: Object.values(PaymentIntentStatus),
        default: PaymentIntentStatus.PENDING,
        index: true
    },
    vnpayTxnRef: { type: String },
    createdAt: { type: Date, default: Date.now },
    expiresAt: { type: Date, required: true, index: true },
    completedAt: { type: Date }
});

// Compound indexes
paymentIntentSchema.index({ groupId: 1, payerId: 1, status: 1 });
paymentIntentSchema.index({ status: 1, expiresAt: 1 });

export const PaymentIntent = mongoose.model<IPaymentIntent>('PaymentIntent', paymentIntentSchema);
