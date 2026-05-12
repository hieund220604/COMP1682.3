import { Router } from 'express';
import { authMiddleware } from '../middleware/authMiddleware';
import { savingsController } from '../controller/savingsController';

const router = Router();

router.use(authMiddleware);

// ── Goals ──────────────────────────────────────────────────────────────────────
router.post('/goals', savingsController.createGoal);
router.get('/goals', savingsController.getGoals);
router.get('/goals/:id', savingsController.getGoalById);
router.put('/goals/:id', savingsController.updateGoal);
router.delete('/goals/:id', savingsController.cancelGoal);

// ── Deposits ───────────────────────────────────────────────────────────────────
router.post('/goals/:id/deposits', savingsController.createDeposit);
router.post('/deposits/:id/withdraw', savingsController.withdrawDeposit);

// ── Utilities ──────────────────────────────────────────────────────────────────
router.get('/interest-preview', savingsController.getInterestPreview);
router.get('/goals/:id/projection', savingsController.getGoalProjection);

export default router;
