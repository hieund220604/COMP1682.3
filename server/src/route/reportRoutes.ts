import { Router } from 'express';
import { authMiddleware } from '../middleware/authMiddleware';
import { reportController } from '../controller/reportController';

const router = Router();

router.use(authMiddleware);

router.get('/monthly', reportController.getMonthlyReport);
router.get('/yearly', reportController.getYearlyReport);

export default router;
