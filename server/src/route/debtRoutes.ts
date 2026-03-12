import { Router } from 'express';
import { debtController } from '../controller/debtController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// Get user's debts in a group (tổng hợp nợ)
router.get('/groups/:groupId/debts', authMiddleware, debtController.getUserDebts);

// Get my pending debts (các khoản tôi đang nợ, chờ thanh toán)
router.get('/groups/:groupId/debts/pending', authMiddleware, debtController.getMyPendingDebts);

// Get my pending credits (các khoản người khác đang nợ tôi)
router.get('/groups/:groupId/credits/pending', authMiddleware, debtController.getMyPendingCredits);

// Quick pay debt (tạo settlement và thanh toán ngay)
router.post('/groups/:groupId/debts/quick-pay', authMiddleware, debtController.quickPay);

// Pay settlement with balance
router.post('/settlements/:settlementId/pay-balance', authMiddleware, debtController.payWithBalance);

// Pay settlement with VNPay
router.post('/settlements/:settlementId/pay-vnpay', authMiddleware, debtController.payWithVNPay);

// Get global debt summary (across all groups)
router.get('/debts/summary', authMiddleware, debtController.getAllUserDebts);

export default router;
