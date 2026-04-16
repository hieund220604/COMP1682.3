import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IGroup extends Document {
    _id: Types.ObjectId;
    name: string;
    baseCurrency: string;
    timezone: string;
    description: string;
    joinCode?: string;
    createdBy: string;
    createdAt: Date;
    updatedAt: Date;
    deletedAt?: Date;  // Soft delete timestamp
}

const GroupSchema = new Schema<IGroup>({
    name: {
        type: String,
        required: true,
        trim: true
    },
    baseCurrency: {
        type: String,
        default: 'VND',
        uppercase: true
    },
    timezone: {
        type: String,
        default: 'Asia/Ho_Chi_Minh'
    },
    description: {
        type: String,
        default: ''
    },
    joinCode: {
        type: String,
        unique: true,
        sparse: true,
        uppercase: true,
        trim: true,
    },
    createdBy: {
        type: String,
        required: true
    },
    deletedAt: {
        type: Date,
        default: null
    }
}, {
    timestamps: true,
    collection: 'groups'
});

// Indexes
GroupSchema.index({ createdBy: 1 });

export const Group = mongoose.model<IGroup>('Group', GroupSchema);
