import { Router } from 'express';
import { transactionController } from '../controller/transactionController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// Get transaction summary (must be before /:id to avoid conflict)
router.get('/summary', authMiddleware, transactionController.getTransactionSummary);

// Get current user's transaction history
router.get('/', authMiddleware, transactionController.getMyTransactions);

// Get a specific transaction by ID
router.get('/:id', authMiddleware, transactionController.getTransactionById);

export default router;
