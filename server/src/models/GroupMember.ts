import mongoose, { Schema, Document, Types } from 'mongoose';

export type GroupRole = 'OWNER' | 'ADMIN' | 'USER';

export interface IGroupMember extends Document {
    _id: Types.ObjectId;
    groupId: string;
    userId: string;
    role: GroupRole;
    joinedAt: Date;
    leftAt?: Date;
}

const GroupMemberSchema = new Schema<IGroupMember>({
    groupId: {
        type: String,
        required: true,
        ref: 'Group'
    },
    userId: {
        type: String,
        required: true,
        ref: 'User'
    },
    role: {
        type: String,
        enum: ['OWNER', 'ADMIN', 'USER'],
        default: 'USER'
    },
    joinedAt: {
        type: Date,
        default: Date.now
    },
    leftAt: {
        type: Date,
        default: null
    }
}, {
    timestamps: false,
    collection: 'group_members'
});

// Indexes
GroupMemberSchema.index({ groupId: 1, userId: 1 });
GroupMemberSchema.index({ userId: 1 });
GroupMemberSchema.index({ leftAt: 1 });

export const GroupMember = mongoose.model<IGroupMember>('GroupMember', GroupMemberSchema);
