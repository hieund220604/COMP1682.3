import { Request, Response } from 'express';
import { chatService } from '../service/chatService';
import { ResponseUtil } from '../util/responseUtil';
import { ApiResponse, GetMessagesResponse, SendMessageRequest } from '../type/chat';

export const chatController = {
    // Send a message to a group
    async sendMessage(
        req: Request<{ groupId: string }, {}, SendMessageRequest>,
        res: Response
    ): Promise<void> {
        try {
            const userId = (req as any).user?.userId;
            const { groupId } = req.params;
            const { content, messageType, fileUrl, fileName, replyToId } = req.body;

            if (!content && !fileUrl) {
                return ResponseUtil.validationError(res, 'Message content or file is required');
            }

            const message = await chatService.saveMessage(groupId, userId, {
                content,
                messageType: messageType || 'TEXT',
                fileUrl,
                fileName,
                replyToId
            });

            ResponseUtil.success(res, message, 'Message sent successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to send message');
        }
    },

    // Get messages for a group
    async getMessages(
        req: Request<{ groupId: string }>,
        res: Response<ApiResponse<GetMessagesResponse>>
    ): Promise<void> {
        try {
            const userId = (req as any).user?.userId;
            const { groupId } = req.params;
            const { beforeId, limit } = req.query;

            const result = await chatService.getMessages(
                userId,
                groupId,
                limit ? parseInt(limit as string) : 30,
                beforeId as string | undefined
            );

            ResponseUtil.success(res, result, 'Messages retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get messages');
        }
    }
};
