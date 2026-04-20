// server/src/route/forecastRoutes.ts
import { Router } from 'express';
import { authMiddleware } from '../middleware/authMiddleware';
import { forecastController } from '../controller/forecastController';

const router = Router();

// All forecast routes require authentication
router.use(authMiddleware);

// GET /api/forecast/summary  — must come before /:anything
router.get('/summary', forecastController.getDashboardSummary);

// GET /api/forecast?days=30
router.get('/', forecastController.getForecast);

export default router;
