import { Router } from 'express';
import { chatController } from '../controller/chatController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Chat routes
router.post('/groups/:groupId/messages', chatController.sendMessage);
router.get('/groups/:groupId/messages', chatController.getMessages);

export default router;
