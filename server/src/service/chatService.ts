import { User } from '../models/User';
import { GroupMember } from '../models/GroupMember';
import { Message } from '../models/Message';
import {
    Message as MessageType,
    SendMessageRequest,
    GetMessagesResponse,
    MessageSender,
    ReplyMessage
} from '../type/chat';

// Helper to transform user to MessageSender
const transformSender = (user: { _id: any; displayName: string | null; avatarUrl: string | null }): MessageSender => ({
    id: user._id.toString(),
    displayName: user.displayName,
    avatarUrl: user.avatarUrl
});

// Helper to transform raw message to Message type
const transformMessage = (raw: any): MessageType => ({
    id: raw._id.toString(),
    groupId: raw.groupId,
    senderId: raw.senderId,
    content: raw.content,
    messageType: raw.messageType,
    fileUrl: raw.fileUrl,
    fileName: raw.fileName,
    replyToId: raw.replyToId,
    createdAt: raw.createdAt,
    updatedAt: raw.updatedAt,
    sender: raw.sender ? transformSender(raw.sender) : undefined,
    replyTo: raw.replyTo ? {
        id: raw.replyTo._id.toString(),
        content: raw.replyTo.content,
        messageType: raw.replyTo.messageType,
        sender: transformSender(raw.replyTo.sender)
    } : null
});

export const chatService = {
    // Save a new message
    async saveMessage(
        groupId: string,
        senderId: string,
        data: SendMessageRequest
    ): Promise<MessageType> {
        // Verify user is member of the group
        const membership = await GroupMember.findOne({ groupId, userId: senderId, leftAt: null });

        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }

        // Create message
        const message = await Message.create({
            groupId,
            senderId,
            content: data.content || null,
            messageType: data.messageType,
            fileUrl: data.fileUrl || null,
            fileName: data.fileName || null,
            replyToId: data.replyToId || null
        });

        // Fetch the complete message with sender info
        const populatedMessage = await Message.findById(message._id)
            .populate({
                path: 'senderId',
                select: '_id displayName avatarUrl',
                model: 'User'
            })
            .populate({
                path: 'replyToId',
                select: '_id content messageType senderId',
                model: 'Message',
                populate: {
                    path: 'senderId',
                    select: '_id displayName avatarUrl',
                    model: 'User'
                }
            });

        // Transform populated data
        const result: any = {
            _id: populatedMessage!._id,
            groupId: populatedMessage!.groupId,
            senderId: populatedMessage!.senderId,
            content: populatedMessage!.content,
            messageType: populatedMessage!.messageType,
            fileUrl: populatedMessage!.fileUrl,
            fileName: populatedMessage!.fileName,
            replyToId: populatedMessage!.replyToId,
            createdAt: populatedMessage!.createdAt,
            updatedAt: populatedMessage!.updatedAt,
            sender: (populatedMessage as any).senderId,
            replyTo: (populatedMessage as any).replyToId
        };

        return transformMessage(result);
    },

    // Get messages for a group (limit 30)
    async getMessages(
        userId: string,
        groupId: string,
        limit: number = 30,
        beforeId?: string
    ): Promise<GetMessagesResponse> {
        console.log('getMessages called with userId:', userId, 'groupId:', groupId);

        // Verify user is member of the group
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        console.log('Membership check result:', membership);

        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }

        let query: any = { groupId };

        if (beforeId) {
            const beforeMessage = await Message.findById(beforeId);
            if (beforeMessage) {
                query.createdAt = { $lt: beforeMessage.createdAt };
            }
        }

        const messages = await Message.find(query)
            .sort({ createdAt: -1 })
            .limit(limit + 1)
            .populate({
                path: 'senderId',
                select: '_id displayName avatarUrl',
                model: 'User'
            })
            .populate({
                path: 'replyToId',
                select: '_id content messageType senderId',
                model: 'Message',
                populate: {
                    path: 'senderId',
                    select: '_id displayName avatarUrl',
                    model: 'User'
                }
            });

        const hasMore = messages.length > limit;
        if (hasMore) {
            messages.pop();
        }

        // Transform messages
        const transformedMessages = messages.map((msg: any) => {
            return transformMessage({
                _id: msg._id,
                groupId: msg.groupId,
                senderId: msg.senderId,
                content: msg.content,
                messageType: msg.messageType,
                fileUrl: msg.fileUrl,
                fileName: msg.fileName,
                replyToId: msg.replyToId,
                createdAt: msg.createdAt,
                updatedAt: msg.updatedAt,
                sender: msg.senderId,
                replyTo: msg.replyToId
            });
        }).reverse();

        return {
            messages: transformedMessages,
            hasMore
        };
    }
};
