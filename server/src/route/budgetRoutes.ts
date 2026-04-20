import { Router } from 'express';
import { budgetController } from '../controller/budgetController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require auth
router.use(authMiddleware);

router.get('/summary', budgetController.getMonthlyBudgetSummary);

export default router;
