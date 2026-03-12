import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IExpenseItem extends Document {
    _id: Types.ObjectId;
    expenseId: string;
    name: string;
    price: number;
    quantity: number;
    assignedTo: string;
}

const ExpenseItemSchema = new Schema<IExpenseItem>({
    expenseId: {
        type: String,
        required: true,
        ref: 'Expense'
    },
    name: {
        type: String,
        required: true,
        trim: true
    },
    price: {
        type: Number,
        required: true
    },
    quantity: {
        type: Number,
        default: 1
    },
    assignedTo: {
        type: String,
        required: true,
        ref: 'User'
    }
}, {
    timestamps: false,
    collection: 'expense_items'
});

// Indexes
ExpenseItemSchema.index({ expenseId: 1 });
ExpenseItemSchema.index({ assignedTo: 1 });

export const ExpenseItem = mongoose.model<IExpenseItem>('ExpenseItem', ExpenseItemSchema);
