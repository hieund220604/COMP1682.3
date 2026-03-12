import mongoose, { Schema, Document, Types } from 'mongoose';

export type SplitType = 'EQUAL' | 'EXACT' | 'PERCENT' | 'ITEM_BASED';

export interface IExpense extends Document {
    _id: Types.ObjectId;
    groupId: string;
    title: string;
    amountTotal: number;
    currency: string;
    splitType: SplitType;
    category?: string;
    expenseType?: string;
    paidBy: string;
    expenseDate: Date;
    note?: string;
    groupDeleted: boolean;  // True if group was deleted
    createdAt: Date;
    updatedAt: Date;
}

const ExpenseSchema = new Schema<IExpense>({
    groupId: {
        type: String,
        required: true,
        ref: 'Group'
    },
    title: {
        type: String,
        required: true,
        trim: true
    },
    amountTotal: {
        type: Number,
        required: true
    },
    currency: {
        type: String,
        default: 'VND',
        uppercase: true
    },
    splitType: {
        type: String,
        enum: ['EQUAL', 'EXACT', 'PERCENT', 'ITEM_BASED'],
        required: true
    },
    category: {
        type: String,
        default: null
    },
    expenseType: {
        type: String,
        default: null
    },
    paidBy: {
        type: String,
        required: true,
        ref: 'User'
    },
    expenseDate: {
        type: Date,
        default: Date.now
    },
    note: {
        type: String,
        default: null
    },
    groupDeleted: {
        type: Boolean,
        default: false
    }
}, {
    timestamps: true,
    collection: 'expenses'
});

// Indexes
ExpenseSchema.index({ groupId: 1 });
ExpenseSchema.index({ paidBy: 1 });
ExpenseSchema.index({ expenseDate: -1 });

export const Expense = mongoose.model<IExpense>('Expense', ExpenseSchema);
