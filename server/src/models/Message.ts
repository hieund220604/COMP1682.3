import mongoose, { Schema, Document, Types } from 'mongoose';

export type MessageType = 'TEXT' | 'IMAGE' | 'FILE';

export interface IMessage extends Document {
    _id: Types.ObjectId;
    groupId: string;
    senderId: string;
    content?: string;
    messageType: MessageType;
    fileUrl?: string;
    fileName?: string;
    replyToId?: string;
    createdAt: Date;
    updatedAt: Date;
}

const MessageSchema = new Schema<IMessage>({
    groupId: {
        type: String,
        required: true,
        ref: 'Group'
    },
    senderId: {
        type: String,
        required: true,
        ref: 'User'
    },
    content: {
        type: String,
        default: null
    },
    messageType: {
        type: String,
        enum: ['TEXT', 'IMAGE', 'FILE'],
        default: 'TEXT'
    },
    fileUrl: {
        type: String,
        default: null
    },
    fileName: {
        type: String,
        default: null
    },
    replyToId: {
        type: String,
        ref: 'Message',
        default: null
    }
}, {
    timestamps: true,
    collection: 'messages'
});

// Indexes
MessageSchema.index({ groupId: 1, createdAt: -1 });
MessageSchema.index({ senderId: 1 });
MessageSchema.index({ replyToId: 1 });

export const Message = mongoose.model<IMessage>('Message', MessageSchema);
