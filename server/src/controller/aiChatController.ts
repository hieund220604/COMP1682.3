import { Request, Response } from 'express';
import { AiChatService } from '../service/aiChatService';

export const aiChatController = {
    async sendMessage(req: Request, res: Response) {
        try {
            const { message, sessionId } = req.body;
            const userId = req.user?.userId;

            if (!userId) {
                return res.status(401).json({ success: false, message: 'Unauthorized' });
            }

            if (!message || typeof message !== 'string') {
                return res.status(400).json({ success: false, message: 'Message is required' });
            }

            const result = await AiChatService.sendMessage(userId, message, sessionId);
            
            res.json({
                success: true,
                data: result
            });
        } catch (error: any) {
            console.error('[aiChatController.sendMessage] Error:', error);
            res.status(500).json({
                success: false,
                message: error.message || 'Failed to send message'
            });
        }
    },

    async getSessions(req: Request, res: Response) {
        try {
            const userId = req.user?.userId;
            if (!userId) {
                return res.status(401).json({ success: false, message: 'Unauthorized' });
            }

            const sessions = await AiChatService.getSessions(userId);
            res.json({ success: true, data: sessions });
        } catch (error: any) {
            console.error('[aiChatController.getSessions] Error:', error);
            res.status(500).json({ success: false, message: 'Failed to get sessions' });
        }
    },

    async getSessionHistory(req: Request, res: Response) {
        try {
            const userId = req.user?.userId;
            const { id } = req.params;
            
            if (!userId) {
                return res.status(401).json({ success: false, message: 'Unauthorized' });
            }

            const history = await AiChatService.getSessionHistory(userId, id);
            res.json({ success: true, data: history });
        } catch (error: any) {
            console.error('[aiChatController.getSessionHistory] Error:', error);
            res.status(500).json({ success: false, message: 'Failed to get session history' });
        }
    }
};
