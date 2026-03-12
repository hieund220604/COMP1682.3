import { Router } from 'express';
import { groupController } from '../controller/groupController';
import { transactionController } from '../controller/transactionController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router();

// All routes require authentication
router.use(authMiddleware);

// Group CRUD
router.post('/', groupController.createGroup);
router.get('/', groupController.getUserGroups);
router.get('/:groupId', groupController.getGroupById);
router.patch('/:groupId', groupController.updateGroup);
router.delete('/:groupId', groupController.deleteGroup);

// Invites
router.get('/invites/pending', groupController.getPendingInvites); // Must be before :groupId routes
router.post('/:groupId/invites', groupController.createInvite);
router.post('/invites/accept', groupController.acceptInvite);

// Members
router.get('/:groupId/members', groupController.getGroupMembers);
router.patch('/:groupId/members/:memberId/role', groupController.updateMemberRole);
router.post('/:groupId/members/:memberId/grant-admin', groupController.grantAdmin);
router.post('/:groupId/transfer-ownership', groupController.transferOwnership);
router.delete('/:groupId/members/:memberId', groupController.removeMember);
router.post('/:groupId/leave', groupController.leaveGroup);

// Balance
router.get('/:groupId/balance', groupController.getGroupBalance);
router.get('/:groupId/balances', groupController.getGroupBalances); // All member balances from ledger

// Transactions
router.get('/:groupId/transactions', transactionController.getGroupTransactions);

export default router;

