import { Router } from 'express';
import { exchangeRateController } from '../controller/exchangeRateController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Exchange rate endpoints
router.get('/convert', exchangeRateController.convert);
router.get('/rate', exchangeRateController.getRate);
router.get('/currencies', exchangeRateController.getSupportedCurrencies);

export default router;
