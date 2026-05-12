import mongoose, { Schema, Document, Types } from 'mongoose';

export interface ISavingsGoal extends Document {
    _id: Types.ObjectId;
    userId: string;
    name: string;
    targetAmount: number;
    currentAmount: number;      // Sum of active deposit principals
    icon: string;
    status: 'ACTIVE' | 'COMPLETED' | 'CANCELLED';
    deadline?: Date;
    createdAt: Date;
    updatedAt: Date;
}

const SavingsGoalSchema = new Schema<ISavingsGoal>({
    userId: {
        type: String,
        required: true,
        ref: 'User',
        index: true,
    },
    name: {
        type: String,
        required: true,
        trim: true,
        maxlength: 100,
    },
    targetAmount: {
        type: mongoose.Schema.Types.Decimal128,
        required: true,
        validate: {
            validator: (v: any) => {
                const num = Number(v);
                return !isNaN(num) && num >= 0;
            },
            message: 'targetAmount must be a non-negative number',
        },
    } as any,
    currentAmount: {
        type: mongoose.Schema.Types.Decimal128,
        default: mongoose.Types.Decimal128.fromString('0'),
        validate: {
            validator: (v: any) => {
                const num = Number(v);
                return !isNaN(num) && num >= 0;
            },
            message: 'currentAmount must be a non-negative number',
        },
    } as any,
    icon: {
        type: String,
        default: '🎯',
        trim: true,
    },
    status: {
        type: String,
        enum: ['ACTIVE', 'COMPLETED', 'CANCELLED'],
        default: 'ACTIVE',
    },
    deadline: {
        type: Date,
        default: null,
    },
}, {
    timestamps: true,
    collection: 'savings_goals',
    toJSON: {
        getters: true,
        transform: (_doc: any, ret: any) => {
            const d128 = (v: any) =>
                v && typeof v === 'object' && typeof v.toString === 'function'
                    ? parseFloat(v.toString())
                    : v;
            ret.targetAmount = d128(ret.targetAmount);
            ret.currentAmount = d128(ret.currentAmount);
            return ret;
        },
    },
    toObject: { getters: true },
});

// Virtual: sum of active deposit principals (status != WITHDRAWN)
SavingsGoalSchema.virtual('actualCurrentAmount').get(async function () {
    const deposits = await mongoose.model('SavingsDeposit').find({
        goalId: this._id,
        status: { $in: ['HOLDING', 'MATURED'] },
    }).select('amount');
    const sum = deposits.reduce((s, d) => s + Number(d.amount), 0);
    return sum;
});

SavingsGoalSchema.index({ userId: 1, status: 1 });

export const SavingsGoal = mongoose.model<ISavingsGoal>('SavingsGoal', SavingsGoalSchema);
