import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IOriginalDebt extends Document {
    _id: Types.ObjectId;
    groupId: string;
    invoiceId: string;        // Original invoice
    debtorId: string;         // Person who owes
    creditorId: string;       // Person to receive (invoice uploader)
    originalAmount: number;   // Original debt amount (in group baseCurrency)
    remainingAmount: number;  // Remaining amount to pay (in group baseCurrency)

    // Exchange rate lock (set when invoice currency !== group baseCurrency)
    originalCurrency?: string;          // Invoice currency (e.g. 'JPY')
    originalAmountInCurrency?: number;  // Debt amount in invoice currency
    exchangeRateUsed?: number;          // Locked rate: 1 originalCurrency = X baseCurrency
    rateLockedAt?: Date;                // When the rate was locked

    createdAt: Date;
}

const OriginalDebtSchema = new Schema<IOriginalDebt>({
    groupId: {
        type: String,
        required: true,
        ref: 'Group',
        index: true
    },
    invoiceId: {
        type: String,
        required: true,
        ref: 'Invoice',
        index: true
    },
    debtorId: {
        type: String,
        required: true,
        ref: 'User',
        index: true
    },
    creditorId: {
        type: String,
        required: true,
        ref: 'User',
        index: true
    },
    originalAmount: {
        type: Number,
        required: true
    },
    remainingAmount: {
        type: Number,
        required: true
    },
    // Exchange rate lock fields
    originalCurrency: {
        type: String,
        default: null,
        uppercase: true
    },
    originalAmountInCurrency: {
        type: Number,
        default: null
    },
    exchangeRateUsed: {
        type: Number,
        default: null
    },
    rateLockedAt: {
        type: Date,
        default: null
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'original_debts'
});

// Compound indexes (ESR: Equality → Sort → Range)
OriginalDebtSchema.index({ groupId: 1, debtorId: 1 });      // getDebtsBetweenUsers, allocateDebtsForTransfer, reduceDebtsBetweenUsers
OriginalDebtSchema.index({ groupId: 1, creditorId: 1 });     // settlement engine, getUserDebtsInGroup
OriginalDebtSchema.index({ groupId: 1, remainingAmount: 1 }); // dashboard debt overview, settlement engine full scan

export const OriginalDebt = mongoose.model<IOriginalDebt>('OriginalDebt', OriginalDebtSchema);
