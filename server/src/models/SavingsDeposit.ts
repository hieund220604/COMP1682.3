import mongoose, { Schema, Document, Types } from 'mongoose';

export interface ISavingsDeposit extends Document {
    _id: Types.ObjectId;
    goalId: Types.ObjectId;
    userId: string;
    amount: number;             // Principal deposited
    term: number;               // Days: 0=flexible, 30, 90, 180, 360
    annualRate: number;         // Annual interest rate (%)
    accruedInterest: number;    // Interest accrued so far
    status: 'HOLDING' | 'MATURED' | 'WITHDRAWN';
    depositDate: Date;
    maturityDate?: Date;        // depositDate + term (null if flexible)
    withdrawnAt?: Date;
    createdAt: Date;
}

const SavingsDepositSchema = new Schema<ISavingsDeposit>({
    goalId: {
        type: Schema.Types.ObjectId,
        required: true,
        ref: 'SavingsGoal',
        index: true,
    },
    userId: {
        type: String,
        required: true,
        ref: 'User',
        index: true,
    },
    amount: {
        type: mongoose.Schema.Types.Decimal128,
        required: true,
        validate: {
            validator: (v: any) => {
                const num = Number(v);
                return !isNaN(num) && num >= 0;
            },
            message: 'amount must be a non-negative number',
        },
    } as any,
    term: {
        type: Number,
        required: true,
        enum: [0, 30, 90, 180, 365],
        default: 0,
    },
    annualRate: {
        type: Number,
        required: true,
        validate: {
            validator: (v: any) => {
                const num = Number(v);
                return !isNaN(num) && num >= 0;
            },
            message: 'annualRate must be a non-negative number',
        },
    },
    accruedInterest: {
        type: mongoose.Schema.Types.Decimal128,
        default: mongoose.Types.Decimal128.fromString('0'),
    } as any,
    status: {
        type: String,
        enum: ['HOLDING', 'MATURED', 'WITHDRAWN'],
        default: 'HOLDING',
    },
    depositDate: {
        type: Date,
        required: true,
        default: Date.now,
    },
    maturityDate: {
        type: Date,
        default: null,
    },
    withdrawnAt: {
        type: Date,
        default: null,
    },
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'savings_deposits',
    toJSON: {
        getters: true,
        transform: (_doc: any, ret: any) => {
            const d128 = (v: any) =>
                v && typeof v === 'object' && typeof v.toString === 'function'
                    ? parseFloat(v.toString())
                    : v;
            ret.amount = d128(ret.amount);
            ret.accruedInterest = d128(ret.accruedInterest);
            return ret;
        },
    },
    toObject: { getters: true },
});

SavingsDepositSchema.index({ userId: 1, status: 1 });
SavingsDepositSchema.index({ goalId: 1, status: 1 });
SavingsDepositSchema.index({ maturityDate: 1, status: 1 });

export const SavingsDeposit = mongoose.model<ISavingsDeposit>('SavingsDeposit', SavingsDepositSchema);
