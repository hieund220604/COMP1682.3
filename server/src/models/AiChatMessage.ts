import mongoose, { Schema, Document, Types } from 'mongoose';

export type AiRole = 'user' | 'model' | 'function';

export interface IAiChatMessage extends Document {
    _id: Types.ObjectId;
    sessionId: Types.ObjectId;
    role: AiRole;
    content: string; // Storing as JSON string if function call/response
    functionCallName?: string;
    createdAt: Date;
    updatedAt: Date;
}

const AiChatMessageSchema = new Schema<IAiChatMessage>({
    sessionId: {
        type: Schema.Types.ObjectId,
        required: true,
        ref: 'AiChatSession',
        index: true
    },
    role: {
        type: String,
        enum: ['user', 'model', 'function'],
        required: true
    },
    content: {
        type: String,
        required: true
    },
    functionCallName: {
        type: String,
        default: null
    }
}, {
    timestamps: true,
    collection: 'ai_chat_messages'
});

export const AiChatMessage = mongoose.model<IAiChatMessage>('AiChatMessage', AiChatMessageSchema);
