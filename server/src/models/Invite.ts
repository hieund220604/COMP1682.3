import mongoose, { Schema, Document, Types } from 'mongoose';

export type InviteStatus = 'PENDING' | 'ACCEPTED' | 'EXPIRED';

export interface IInvite extends Document {
    _id: Types.ObjectId;
    groupId: string;
    emailInvite: string;
    role: string;
    token: string;
    status: InviteStatus;
    expiredAt: Date;
    invitedBy?: string;
    createdAt: Date;
}

const InviteSchema = new Schema<IInvite>({
    groupId: {
        type: String,
        required: true,
        ref: 'Group'
    },
    emailInvite: {
        type: String,
        required: true,
        lowercase: true,
        trim: true
    },
    role: {
        type: String,
        enum: ['OWNER', 'ADMIN', 'USER'],
        default: 'USER'
    },
    token: {
        type: String,
        required: true,
        unique: true
    },
    status: {
        type: String,
        enum: ['PENDING', 'ACCEPTED', 'EXPIRED'],
        default: 'PENDING'
    },
    expiredAt: {
        type: Date,
        required: true
    },
    invitedBy: {
        type: String,
        ref: 'User',
        default: null
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'invites'
});

// Indexes

InviteSchema.index({ groupId: 1, emailInvite: 1 });
InviteSchema.index({ status: 1 });

export const Invite = mongoose.model<IInvite>('Invite', InviteSchema);
