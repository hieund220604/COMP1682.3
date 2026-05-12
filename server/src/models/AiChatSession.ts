import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IAiChatSession extends Document {
    _id: Types.ObjectId;
    userId: string;
    title: string;
    createdAt: Date;
    updatedAt: Date;
}

const AiChatSessionSchema = new Schema<IAiChatSession>({
    userId: {
        type: String,
        required: true,
        ref: 'User',
        index: true
    },
    title: {
        type: String,
        required: true,
        default: 'New Chat'
    }
}, {
    timestamps: true,
    collection: 'ai_chat_sessions'
});

export const AiChatSession = mongoose.model<IAiChatSession>('AiChatSession', AiChatSessionSchema);
