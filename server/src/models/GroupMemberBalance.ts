import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IGroupMemberBalance extends Document {
    _id: Types.ObjectId;
    groupId: string;
    userId: string;
    netBalance: number;
    lastUpdated: Date;
}

const groupMemberBalanceSchema = new Schema<IGroupMemberBalance>({
    groupId: { type: String, required: true, index: true },
    userId: { type: String, required: true, index: true },
    netBalance: { type: Number, required: true, default: 0 },
    lastUpdated: { type: Date, default: Date.now }
});

// Unique constraint: one balance record per user per group
groupMemberBalanceSchema.index({ groupId: 1, userId: 1 }, { unique: true });

export const GroupMemberBalance = mongoose.model<IGroupMemberBalance>(
    'GroupMemberBalance',
    groupMemberBalanceSchema
);
