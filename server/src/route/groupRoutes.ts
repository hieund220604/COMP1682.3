import { Router } from 'express';
import { groupController } from '../controller/groupController';
import { transactionController } from '../controller/transactionController';
import { authMiddleware } from '../middleware/authMiddleware';
import { createRateLimit } from '../middleware/rateLimitMiddleware';

const router = Router();

// ── Per-user rate limits ───────────────────────────────────────────────
const groupCreateLimiter = createRateLimit({
    keyPrefix: 'group:create',
    windowMs: 60 * 60 * 1000,
    maxRequests: 10,
    message: 'Group creation limit reached. Please try again later.',
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

const groupWriteLimiter = createRateLimit({
    keyPrefix: 'group:write',
    windowMs: 60_000,
    maxRequests: 20,
    keyGenerator: (req) => req.user?.userId || req.ip || 'anon'
});

// ── Per-IP rate limits ─────────────────────────────────────────────────
const groupWriteIpLimiter = createRateLimit({
    keyPrefix: 'group:write:ip',
    windowMs: 60_000,
    maxRequests: 50,
    keyGenerator: (req) => req.ip || 'unknown'
});

// All routes require authentication
router.use(authMiddleware);

// Group CRUD
router.post('/', groupWriteIpLimiter, groupCreateLimiter, groupController.createGroup);
router.get('/', groupController.getUserGroups);
router.get('/:groupId', groupController.getGroupById);
router.patch('/:groupId', groupWriteIpLimiter, groupWriteLimiter, groupController.updateGroup);
router.delete('/:groupId', groupWriteIpLimiter, groupWriteLimiter, groupController.deleteGroup);

// Invites
router.get('/invites/pending', groupController.getPendingInvites);
router.post('/:groupId/invites', groupWriteIpLimiter, groupWriteLimiter, groupController.createInvite);
router.post('/invites/accept', groupWriteIpLimiter, groupWriteLimiter, groupController.acceptInvite);
router.post('/join-by-code', groupWriteIpLimiter, groupWriteLimiter, groupController.joinByCode);

// Members
router.get('/:groupId/members', groupController.getGroupMembers);
router.patch('/:groupId/members/:memberId/role', groupWriteIpLimiter, groupWriteLimiter, groupController.updateMemberRole);
router.post('/:groupId/members/:memberId/grant-admin', groupWriteIpLimiter, groupWriteLimiter, groupController.grantAdmin);
router.post('/:groupId/transfer-ownership', groupWriteIpLimiter, groupWriteLimiter, groupController.transferOwnership);
router.delete('/:groupId/members/:memberId', groupWriteIpLimiter, groupWriteLimiter, groupController.removeMember);
router.post('/:groupId/leave', groupWriteIpLimiter, groupWriteLimiter, groupController.leaveGroup);

// Balance
router.get('/:groupId/balance', groupController.getGroupBalance);

// Transactions
router.get('/:groupId/transactions', transactionController.getGroupTransactions);

export default router;

