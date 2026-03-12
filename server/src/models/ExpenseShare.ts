import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IExpenseShare extends Document {
    _id: Types.ObjectId;
    expenseId: string;
    userId: string;
    owedAmount: number;
    shareNote?: string;
}

const ExpenseShareSchema = new Schema<IExpenseShare>({
    expenseId: {
        type: String,
        required: true,
        ref: 'Expense'
    },
    userId: {
        type: String,
        required: true,
        ref: 'User'
    },
    owedAmount: {
        type: Number,
        required: true
    },
    shareNote: {
        type: String,
        default: null
    }
}, {
    timestamps: false,
    collection: 'expense_shares'
});

// Indexes
ExpenseShareSchema.index({ expenseId: 1 });
ExpenseShareSchema.index({ userId: 1 });

export const ExpenseShare = mongoose.model<IExpenseShare>('ExpenseShare', ExpenseShareSchema);
