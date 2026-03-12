import { Router } from 'express';
import { settlementController } from '../controller/settlementController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Settlement routes
router.post('/:groupId/settlements', settlementController.createSettlement);
router.get('/:groupId/settlements', settlementController.getSettlementsByGroup);
router.get('/:groupId/settlements/suggested', settlementController.getSuggestedSettlements);

export default router;
