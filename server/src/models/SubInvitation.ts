import mongoose, { Schema, Document, Types } from 'mongoose';

export type SubInvitationStatus = 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'EXPIRED';

export interface ISubInvitation extends Document {
    _id: Types.ObjectId;
    subscriptionId: string;
    inviteeId: string;
    invitedBy: string;          // = ownerId
    status: SubInvitationStatus;
    expiresAt: Date;
    createdAt: Date;
}

const SubInvitationSchema = new Schema<ISubInvitation>({
    subscriptionId: {
        type: String,
        required: true,
        ref: 'Subscription'
    },
    inviteeId: {
        type: String,
        required: true,
        ref: 'User'
    },
    invitedBy: {
        type: String,
        required: true,
        ref: 'User'
    },
    status: {
        type: String,
        enum: ['PENDING', 'ACCEPTED', 'DECLINED', 'EXPIRED'],
        default: 'PENDING'
    },
    expiresAt: {
        type: Date,
        required: true,
        default: () => new Date(Date.now() + 7 * 24 * 60 * 60 * 1000) // +7 days
    }
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'sub_invitations'
});

// Prevent duplicate PENDING invitations for the same (sub, invitee) pair
SubInvitationSchema.index(
    { subscriptionId: 1, inviteeId: 1, status: 1 },
    { unique: false }
);
SubInvitationSchema.index({ subscriptionId: 1 });
SubInvitationSchema.index({ inviteeId: 1 });
SubInvitationSchema.index({ expiresAt: 1 });

export const SubInvitation = mongoose.model<ISubInvitation>('SubInvitation', SubInvitationSchema);
