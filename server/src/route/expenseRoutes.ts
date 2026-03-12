import { Router } from 'express';
import { expenseController } from '../controller/expenseController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Expense CRUD
router.post('/:groupId/expenses', expenseController.createExpense);
router.get('/:groupId/expenses', expenseController.getExpensesByGroup);
router.get('/:groupId/expenses/:expenseId', expenseController.getExpenseById);
router.patch('/:groupId/expenses/:expenseId', expenseController.updateExpense);
router.delete('/:groupId/expenses/:expenseId', expenseController.deleteExpense);

export default router;
