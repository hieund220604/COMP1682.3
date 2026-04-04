import { Router } from 'express';
import { authMiddleware } from '../middleware/authMiddleware';
import { dashboardController } from '../controller/dashboardController';

const router = Router();

router.use(authMiddleware);

router.get('/home', dashboardController.getPersonalDashboard);
router.get('/group/:groupId', dashboardController.getGroupDashboard);

export default router;
